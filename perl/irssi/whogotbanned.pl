use strict;
use warnings FATAL => qw(all);

use Irssi;
use Irssi::Irc;

{ package Irssi::Nick; } # God-dammed "Can't find Irssi::Nick for @Irssi::Irc::Nick::ISA'

our $VERSION = '1';

our %IRSSI = (
	authors => 'aquanight',
	name => 'whogotbanned',
	description => 'Display who got banned when a ban (+b) is set',
	license => 'public domain',
);

sub sig_message_irc_mode {
	my ($server, $target, $nick, $addr, $mode) = @_;
	$nick = $server->{real_address} unless $nick;
	return unless defined($nick) && defined($addr);
	return if $server->ignore_check($nick, $addr, $target, $mode, MSGLEVEL_MODES);
	my $chantypes = $server->isupport("CHANTYPES");
	my @chanmodes = split /,/, $server->isupport("CHANMODES");
	if ($target =~ m/^[\Q$chantypes\E]/) {
		my $chptr = $server->channel_find($target);
		return unless ref($chptr) eq "Irssi::Irc::Channel";
		my @banmasks = ();
		my @exceptmasks = ();
		my @invitemasks = ();
		my @modechange = split / /, $mode;
		# Unfortunately, we have to manually parse the mode change :\
		my $realmodes = shift(@modechange);
		my $adding = 1;
		for (my $idx = 0; $idx < length($realmodes); ++$idx) {
			my $modechar = substr($realmodes, $idx, 1);
			my $regex = qr/\Q$modechar\E/;
			if ($modechar eq '+') {
				$adding = 1;
			} elsif ($modechar eq '-') {
				$adding = 0;
			} elsif ($chanmodes[0] =~ $regex) {
				# List modes, this is where bans pop up.
				my $param = shift(@modechange);
				if ($adding && $modechar eq 'b') {
#					# Ban.
					push @banmasks, $param;
				}
				if ($adding && $modechar eq 'e') {
#					# Exception.
					push @exceptmasks, $param;
				}
				if ($adding && $modechar eq 'I') {
#					# Invite.
					push @invitemasks, $param;
				}
			} elsif ($chanmodes[1] =~ $regex || ($chanmodes[2] =~ $regex && $adding)) {
				shift @modechange;
			} else {
				# Do nothing.
			}
		}
		my @nicksbanned;
		my @nicksexempt;
		my @nicksinvite;
		my $banmasks = join " ", @banmasks;
		my $excmasks = join " ", @exceptmasks;
		my $invmasks = join " ", @invitemasks;
		for my $nick ($chptr->nicks()) {
			next unless $nick->{host}; # Skip if not synched.
			push @nicksbanned, $nick->{nick} if Irssi::masks_match($banmasks, $nick->{nick}, $nick->{host});
			push @nicksexempt, $nick->{nick} if Irssi::masks_match($excmasks, $nick->{nick}, $nick->{host});
			push @nicksinvite, $nick->{nick} if Irssi::masks_match($invmasks, $nick->{nick}, $nick->{host});
		}
		# NOTE: keys(%formats) does not work because hash keys are RANDOMLY ORDERED. This order lets us use a simple bitmask:
		# Bit 0 = Ban, Bit 1 = Exempt, Bit 2 = Invite
		my @formats = ("mode_bannednicks", "mode_exemptnicks", "mode_banexcnicks", "mode_invitenicks", "mode_baninvnicks", "mode_excinvnicks", "mode_bnexinnicks");
		my $whichformat = (scalar(@nicksbanned) > 0 ? 0x1 : 0x0) | (scalar(@nicksexempt) > 0 ? 0x2 : 0x0) | (scalar(@nicksinvite) > 0 ? 0x4 : 0x0);
		if ($whichformat > 0) {
			$chptr->printformat(MSGLEVEL_MODES, ($nick =~ m/\./ ? 'serv' : '') . $formats[$whichformat - 1], $target, $mode, $nick,
				join(" ", @nicksbanned), join(" ", @nicksexempt), join(" ", @nicksinvite));
			Irssi::signal_stop();
		}
	}
}

# IMPORTANT: Use $3 for list of banned nicks, $4 for list of exempt nicks, $5 for list of invite nicks, *ALWAYS*.
my %formats = (
	mode_bannednicks => 'mode/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}]',
	mode_exemptnicks => 'mode/{channelhilight $0} {mode $1} by {nick $2} [Exempt: {nick $4}]',
	mode_invitenicks => 'mode/{channelhilight $0} {mode $1} by {nick $2} [Invite: {nick $5}]',
	mode_banexcnicks => 'mode/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}] [Exempt: {nick $4}]',
	mode_baninvnicks => 'mode/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}] [Invite: {nick $5}]',
	mode_excinvnicks => 'mode/{channelhilight $0} {mode $1} by {nick $2} [Exempt: {nick $4}] [Invite: {nick $5}]',
	mode_bnexinnicks => 'mode/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}] [Exempt: {nick $4}] [Invite: {nick $5}]',
	servmode_bannednicks => '{netsplit ServerMode}/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}]',
	servmode_exemptnicks => '{netsplit ServerMode}/{channelhilight $0} {mode $1} by {nick $2} [Exempt: {nick $4}]',
	servmode_invitenicks => '{netsplit ServerMode}/{channelhilight $0} {mode $1} by {nick $2} [Invite: {nick $5}]',
	servmode_banexcnicks => '{netsplit ServerMode}/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}] [Exempt: {nick $4}]',
	servmode_baninvnicks => '{netsplit ServerMode}/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}] [Invite: {nick $5}]',
	servmode_excinvnicks => '{netsplit ServerMode}/{channelhilight $0} {mode $1} by {nick $2} [Exempt: {nick $4}] [Invite: {nick $5}]',
	servmode_bnexinnicks => '{netsplit ServerMode}/{channelhilight $0} {mode $1} by {nick $2} [Banned: {nick $3}] [Exempt: {nick $4}] [Invite: {nick $5}]',

);

Irssi::theme_register([%formats]);

Irssi::signal_add("message irc mode", \&sig_message_irc_mode);
