use Irssi;
use Irssi::Irc;
use strict;
use warnings FATAL => 'all';
use vars qw($VERSION %IRSSI);
use Data::Dumper;

use CommonStuff;

$VERSION = '1';
%IRSSI = (
	authors => 'aquanight',
	name => 'services',
	description => 'Makes it easier to use services',
	license => 'public domain'
);

#### Data Section ####

our $serviceData = {};

# The current format:
# chatnet => {
#	NickServ => n!u@h mask of NickServ
#	ChanServ => n!u@h mask of ChanServ
#	plzident => qr/What NickServ says for identify request./
#	nickpass => {
#		nick => identify command
#	}
# }

sub load_service_data () {
	local $_;
	my $file = Irssi::get_irssi_dir . "/services.config";
	eval {
		do "$file"; # TODO - Put security clamps on this.
	};
	if ($@) {
		Irssi::printformat('load_error', $@);
		# Leave old settings alone now.
		die unless defined($serviceData);
		return;
	}
	my $chatnets = scalar(keys(%$serviceData));
	my $nicks = 0;
	for (keys(%$serviceData)) {
		if (ref($serviceData->{$_}{nickpass}) ne "HASH")
		{
			$nicks++;
		}
		else
		{
			$nicks += scalar(keys(%{$serviceData->{$_}{nickpass}}));
		}
	}
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'loaded_data', $chatnets, $nicks, $file);
}

sub save_service_data () {
	local $_;
	my ($file) = Irssi::get_irssi_dir . "/services.config";
	my $fd;
	local $Dumper::Purity = 1; # Recursively process references I guess.
	local $Dumper::Useqq = 1; # Use "" and quote stuff. Slow.
	local $Dumper::Quotekeys = 1;
	local $Dumper::Sortkeys = 1;
	open $fd, '>', $file;
	print $fd, "use strict;\nuse warnings FATAL => qw(all);\nuse Irssi;\n";
	print $fd, Data::Dumper->Dump([$serviceData], 'serviceData');
	close $fd;
}

#### Basic Functions ####

sub sendf($$@) {
	local $_;
	my ($server, $witem, $cmdformat, @args) = @_;
	my $cmd = sprintf($cmdformat, @args);
	if (Irssi::settings_get_bool('pretend_send')) {
		$witem->printformat(MSGLEVEL_CLIENTCRAP, 'svscmd_pretend', $cmd);
	} else {
		$server->send_raw($cmd);
	}
}

#### NickServ Stuff ####

# Processes a command list, aka a list of irssi commands or possibly subs.
# $server - Server that we're processing stuff for.
# $list - Command list to process.
# @args - Extra arguments one can pass to a called sub reference.
# List can be any one of the following, which dictates how it is processed:
# Nonreference or reference to scalar - sent as Irssi command ($server->command()).
# Reference to array - Each entry processed recursively, in order.
# Reference to hash - Hash entry with the $server current nick is selected and processed recursively.
# Reference to code (sub {} or \&sub) - Subroutine invoked with the argument $server, followed by anything that was passed to @args.
sub process_command_list($$@); # Darn perl needing predeclares for recursive subs.

sub process_command_list($$@) {
	my ($server, $list, @args) = @_;
	my $type = ref($list);
	die "Undefined list" unless defined($list);
	die "ref handed us undef" unless defined($type);
	if ($type eq "") {
		# Scalar String
		$server->command($list);
	} elsif ($type eq "SCALAR") {
		# Scalar Reference (deref and run).
		@_ = ($server, $$list, @args);
		goto &process_command_list;
	} elsif ($type eq "ARRAY") {
		# Array reference, execute each command seperately in order. Yes we could make them use ; seperation
		# for this, but oh well. More than one way to do something then.
		for my $cmd (@$list)
		{
			process_command_list($server, $cmd, @args);
		}
	} elsif ($type eq "HASH") {
		if (exists($list->{$server->{nick}})) {
			@_ = ($server, $list->{$server->{nick}}, @args);
			goto &process_command_list;
		}
	} elsif ($type eq "CODE") {
		@_ = ($server, @args);
		goto &$list;
	} else {
		Irssi::print "Warning: invalid reference type '$type' in command list";
	}
}

sub nickserv_msg {
	local $_;
	my ($server, $msg, $nick, $address, $target, $data) = @_;
	my $plzregex = $data->{plzident};
	my $okregex = $data->{identok};
	my @captures;
	if (defined($plzregex) && (@captures = ($msg =~ m/$plzregex/))) {
		if (exists($data->{nickpass})) {
			Irssi::print "Sending identification...";
			process_command_list($server, $data->{nickpass}, @captures);
		}
	}
	if (defined($okregex) && (@captures = ($msg =~ m/$okregex/))) {
		if (exists($data->{postident})) {
			Irssi::print "Processing post-identify...";
			process_command_list($server, $data->{postident}, @captures);
		}
	}
}

#### ChanServ Stuff ####

sub chanserv_msg {
	local $_;
	my ($server, $msg, $nick, $address) = @_;

}

# Command: /qakick nick reason
# Adds a ChanServ AKICK, uses /set ban_type to get mask type.
sub cmd_qakick {
	local $_;
	my ($data, $server, $witem) = @_;
	my ($nick, $reason) = split " ", $data, 2;
	my ($acptr);
	# XXX: Using "magic numbers" for error command signals because Irssi doesn't expose the constants for them.
	if (!$witem || $witem->{type} ne "CHANNEL") {
		Irssi::signal_emit("error command", 5); # Not joined to any channel.
		Irssi::signal_stop();
		return;
	}
	$acptr = $witem->nick_find($nick);
	if (!$acptr) {
		$witem->printformat(MSGLEVEL_CLIENTERROR, 'qakick_nouser', $nick, $witem->{name});
		Irssi::signal_stop();
		return;
	}
	if (!$acptr->{host}) {
		Irssi::signal_emit("error command", 7); # Channel not synced.
		Irssi::signal_stop();
		return;
	}
	my $mask = $witem->ban_get_mask($nick, 0); # 0 == Default type.
	$witem->printformat(MSGLEVEL_CLIENTCRAP, 'qakick_adding', $mask, $witem->{name}, $reason);
	sendf($server, $witem, "CHANSERV :AKICK ADD %s %s %s", $witem->{name}, $mask, $reason);
}

#### General Signals ####

sub sig_privmsg {
	local $_;
	my ($server, $msg, $nick, $address, $target) = @_;
	my $data;
	return unless (exists($serviceData->{$server->{chatnet}}));
	return unless defined($nick) && defined($address);
	$data = $serviceData->{$server->{chatnet}};
	push @_, $data; # Stick this on the end.
	if (exists($data->{NickServ}) && defined($data->{NickServ}) && Irssi::mask_match_address($data->{NickServ}, $nick, $address)) {
		goto &nickserv_msg;
	}
	if (exists($data->{ChanServ}) && defined($data->{ChanServ}) && Irssi::mask_match_address($data->{ChanServ}, $nick, $address)) {
		goto &chanserv_msg;
	}
	# Nothing else to do with it atm.
}

sub sig_irc_notice {
	local $_;
	my ($server, $msg, $nick, $address, $target) = @_;
	if ($target eq $server->{nick}) {
		goto &sig_privmsg;
	}
}

sub sig_setup_reread {
	local $_;
	load_service_data;
}

#### Commands ####
sub cmd_identify
{
	my ($args, $server, $witem) = @_;
	my (@args) = split / /, $args, 2;
	my $tag = shift(@args);
	if (defined($tag) && $tag ne "" && $tag ne "*")
	{
		$server = Irssi::server_find_tag("$tag");
		unless (defined($server))
		{
			Irssi::print("Unknown tag '$tag'");
			return;
		}
	}
	if (!defined($server) || !$server->{connected})
	{
		Irssi::signal_emit("error command", 4); # Not connected to server
		return;
	}
	if ($#args > 0)
	{
		local $/ = " ";
		$server->send_raw("IDENTIFY @args");
	}
	else
	{
		my $data = $serviceData->{$server->{chatnet}};
		unless (defined($data) && defined($data->{nickpass}))
		{
			Irssi::print("No identification set up for chatnet " . $server->{chatnet});
			return;
		}
		Irssi::print("Identifying on " . $server->{tag});
		process_command_list($server, $data->{nickpass});
	}
}

Irssi::command_bind(identify => \&cmd_identify);

#### Message Formats ####
my @formats = (
	'svscmd_pretend', 'Would send command {hilight $0}',
	'qakick_nouser', '{line_start}User {nick $0} isn\'t in {channel $1}',
	'qakick_adding', '{line_start}Adding {hilight $0} to AKICK for {channel $1} {comment $2}',
	'loaded_data', '{line_start}{hilight services:} Loaded $0 chatnets with $1 nicks from $2',
	'load_error', '{line_start}{error Failed to load config: {hilight $0-}:}',
);

#### Script Load #####

Irssi::theme_register(\@formats);

Irssi::settings_add_bool('servicescommands', 'pretend_send', 0);

Irssi::command_bind('qakick', 'cmd_qakick');

Irssi::signal_add('message private', 'sig_privmsg');
Irssi::signal_add('message irc notice', 'sig_irc_notice');

Irssi::signal_add('setup reread', 'sig_setup_reread');

load_service_data;
