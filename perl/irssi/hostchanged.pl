use strict;
use warnings FATAL => qw(all);

use Irssi;
use Irssi::Irc;

our $VERSION = 1;
our %IRSSI = (
	authors => 'aquanight',
	name => 'hostchanged',
	description => q|Detect whenever a user's hostname changes, and show it in their messages.|,
	license => 'public domain',
);

sub skip_target($$) {
	my ($server, $target) = @_;
	my $val = $server->isupport("STATUSMSG");
	if (!defined($val)) {
		if (defined($server->isupport("WALLCHOPS"))) {
			$val = "@";
		} else {
			return $target;
		}
	}
	# ### FIXME ### - We need to watch it for an IRCd that has STATUSMSG=@+ and CHANTYPES=#+. Easy, though, as +chan can't have any voices. To be done later.
	$target =~ s/^[\Q$val\E]+//;
	return $target;
}

sub get_nickmode($) {
	my ($cptr) = @_;
	return "" unless (Irssi::settings_get_bool("show_nickmode"));
	my $empty = Irssi::settings_get_bool("show_nickmode_empty") ? " " : "";
	return $empty if !$cptr;
	if ($cptr->{other}) {
		return chr($cptr->{other});
	} elsif ($cptr->{op}) {
		return "@";
	} elsif ($cptr->{halfop}) {
		return "%";
	} elsif ($cptr->{voice}) {
		return "+";
	}
	return $empty;
}

our %address_cache;

sub sig_server_connected {
	my ($server) = @_;
	$address_cache{lc $server->{tag}} = {};
}

sub sig_server_disconnected {
	my ($server) = @_;
	delete $address_cache{lc $server->{tag}};
}

sub sig_channel_created {
	my ($chan) = @_;
	my $server = $chan->{server};
	$address_cache{lc $server->{tag}}->{lc $chan->{name}} = {};
}

sub sig_channel_destroyed {
	my ($chan) = @_;
	my $server = $chan->{server};
	delete $address_cache{lc $server->{tag}}->{lc $chan->{name}};
}

sub sig_nicklist_new {
	my ($chan, $nick) = @_;
	my $server = $chan->{server};
	$address_cache{lc $server->{tag}}->{lc $chan->{name}}->{lc $nick->{nick}} = lc $nick->{host};
}

sub sig_nicklist_remove {
	my ($chan, $nick) = @_;
	my $server = $chan->{server};
	delete $address_cache{lc $server->{tag}}->{lc $chan->{name}}->{lc $nick->{nick}};
}

sub sig_nicklist_changed {
	my ($chan, $nick, $oldnick) = @_;
	my $server = $chan->{server};
	my $hashref = $address_cache{lc $server->{tag}}->{lc $chan->{name}};
	$hashref->{lc $nick->{nick}} = $hashref->{lc $oldnick};
	delete $hashref->{lc $oldnick};
}

sub sig_nicklist_host_changed {
	my ($chan, $nick) = @_;
	my $server = $chan->{server};
	$address_cache{lc $server->{tag}}->{lc $chan->{name}}->{lc $nick->{nick}} = lc $nick->{host};
}

sub has_changed($$$$) {
	my ($server, $chan, $nick, $address) = @_;
	$chan = $chan->{name} if ref($chan) eq "Irssi::Irc::Channel";
	$nick = $nick->{nick} if ref($nick) eq "Irssi::Irc::Nick";
	return 1 unless exists($address_cache{lc $server->{tag}}->{lc $chan}->{lc $nick});
	return lc($address_cache{lc $server->{tag}}->{lc $chan}->{lc $nick}) ne lc($address);
}

sub update_host($$$$) {
	my ($server, $chan, $nick, $address) = @_;
	$chan = $chan->{name} if ref($chan) eq "Irssi::Irc::Channel";
	$nick = $nick->{nick} if ref($nick) eq "Irssi::Irc::Nick";
	$address_cache{lc $server->{tag}}->{lc $chan}->{lc $nick} = lc $address;
}

sub sig_message_public {
	my ($server, $msg, $nick, $address, $target) = @_;
	my $oldtarget = $target;
	my $level = MSGLEVEL_PUBLIC;
	$target = skip_target($server, $target);
	if ($target !~ m/^[#&+!]/) {
		# Not public.
		return;
	}
	my $chptr = $server->channel_find($target);
	if (!$chptr) {
		# No item == channel message from channel *we aren't in*. Send it to status, and always have host.
		$server->printformat($level, "pubact_withhost", $nick, $address, $msg);
		Irssi::signal_stop();
		return;
	}
	my $cptr = $chptr->nick_find($nick);
	if ($cptr && !has_changed($server, $target, $nick, $address)) {
		# Address not changed.
		return;
	}
	my $print_channel = !($chptr && $chptr->is_active()) || Irssi::settings_get_bool("print_active_channel");
	my $nickmode = get_nickmode($cptr);
	if (!$print_channel) {
		$chptr->printformat($level, "pubmsg_withhost", $nickmode, $nick, $address, $msg);
	} else {
		$chptr->printformat($level, "pubmsg_channel_withhost", $nickmode, $nick, $address, $msg);
	}
	update_host($server, $target, $nick, $address); # Only if the nick is known!
	Irssi::signal_stop();
	return;
}

# Only need to handle public actions where the user's user@host has changed.

sub sig_message_irc_action {
	my ($server, $msg, $nick, $address, $target) = @_;
	my $item;
	my $oldtarget = $target;
	$target = skip_target($server, $target);
	if ($target !~ m/^[#&+!]/) {
		# Not public.
		return;
	}
	my $level = MSGLEVEL_ACTIONS | MSGLEVEL_PUBLIC;
	if ($server->ignore_check($nick, $address, $target, $msg, $level)) {
		return;
	}
	$item = $server->channel_find($target);
	if (!$item) {
		# No item == channel message from channel *we aren't in*. Send it to status, and always have host.
		$server->printformat($level, "pubact_withhost", $nick, $address, $msg);
		Irssi::signal_stop();
		return;
	}
	my $cptr = $item->nick_find($nick);
	if ($cptr && !has_changed($server, $target, $nick, $address)) {
		# Address not changed.
		return;
	}
	if ($item->is_active() && $target eq $oldtarget) {
		$item->printformat($level, "pubact_withhost", $nick, $address, $msg);
	} else {
		$item->printformat($level, "pubact_channel_withhost", $nick, $address, $oldtarget, $msg);
	}
	update_host($server, $target, $nick, $address) if ($cptr); # Only if the nick is known!
	Irssi::signal_stop();
	return;
}

my %formats = (
	# $0 = Nickmode, $1 = nick, $2 = user@host, $3 = message
	pubmsg_withhost => '{pubmsgnick $0 {pubnick $1} {chanhost $2}}$3',
	# $0 = Nickmode, $1 = nick, $2 = user@host, $3 = channel, $4 = message
	pubmsg_channel_withhost => '{pubmsgnick $0 {pubnick $1} {chanhost$2}{msgchannel $3}}$4',
	# $0 = Nick, $1 = user@host, $2 = message
	pubact_withhost => '{pubaction $0 {chanhost $1}}$2',
	# $0 = Nick, $1 = user@host, $2 = channel, $3 = message
	pubact_channel_withhost => '{pubaction $0 {chanhost $1}{msgchannel $2}}$3',
);

for my $server (Irssi::servers()) {
	sig_server_connected($server);
}

for my $chptr (Irssi::channels()) {
	sig_channel_created($chptr);
	for my $nick ($chptr->nicks()) {
		sig_nicklist_new($chptr, $nick);
	}
}

Irssi::theme_register([%formats]);

Irssi::signal_add("message public", \&sig_message_public);
Irssi::signal_add("message irc action", \&sig_message_irc_action);

Irssi::signal_add("server connected", \&sig_server_connected);
Irssi::signal_add("server disconnected", \&sig_server_disconnected);
Irssi::signal_add("server connect failed", \&sig_server_disconnected);
Irssi::signal_add("channel created", \&sig_channel_created);
Irssi::signal_add("channel destroyed", \&sig_channel_destroyed);
Irssi::signal_add("nicklist new", \&sig_nicklist_new);
Irssi::signal_add("nicklist remove", \&sig_nicklist_remove);
Irssi::signal_add("nicklist changed", \&sig_nicklist_changed);
Irssi::signal_add("nicklist host changed", \&sig_nicklist_host_changed);

# Commands to debug the address cache.
Irssi::command_bind("address_cache", sub { my ($data, $server, $witem) = @_; Irssi::command_runsub("address_cache", $data, $server, $witem); });
Irssi::command_bind("address_cache clear",
	sub {
		my ($data, $server, $witem) = @_;
		if ($data !~ m/(^|\s)-yes(\s|$)/) {
			Irssi::print("Clearing the address cache will empty it of all nick entries! There are only two reasons to ever do this:");
			Irssi::print("- The address cache has become grossly corrupted (/address_cache check lists many stale nicks, channels, or even servers).");
			Irssi::print("- Using up a lot of memory. Clearing the cache will also shrink it.");
			Irssi::signal_emit("error command", 9); # Confirm with -yes.
			Irssi::print("After clearing the cache, it will be automatically repopulated with active servers or channels, but no nick entries.");
			Irssi::print("Nick entries can be refilled by using: /foreach channel /who");
			return;
		}
		undef %address_cache; # Dump it.
		%address_cache = (); # Redefine with empty hash.
		for my $server (Irssi::servers()) {
			sig_server_connected($server);
		}
		for my $chptr (Irssi::channels()) {
			sig_channel_created($chptr);
		}
	});

Irssi::command_bind("address_cache stats",
	sub {
		my ($data, $server, $witem) = @_;
		if (%address_cache) {
			Irssi::print("Number of buckets used/allocated for main hash: " . scalar(%address_cache));
			Irssi::print("Number of keys in server hash: " . scalar(keys(%address_cache)));
			for my $srvkey (keys(%address_cache)) {
				my $server = $address_cache{$srvkey};
				unless (ref($server) eq "HASH") {
					Irssi::print(" !! Non-hash for $srvkey");
					next;
				}
				Irssi::print(" Buckets used/allocated for $srvkey: " . scalar(%$server));
				Irssi::print(" Number of keys in $srvkey: " . scalar(keys(%$server)));
				for my $chnkey (keys(%$server)) {
					my $channel = $server->{$chnkey};
					unless (ref($channel) eq "HASH") {
						Irssi::print("  !! Non-hash for $chnkey");
						next;
					}
					Irssi::print("  Buckets used/allocated for $chnkey: " . scalar(%$channel));
					Irssi::print("  Number of keys in $chnkey: " . scalar(keys(%$channel)));
				}
			}
		}
	});
Irssi::command_bind("address_cache check",
	sub {
		local $_;
		my ($stales, $errors) = (0, 0); # $stales = number of stale entries, $errors = number of missing entries or nonhashes.
		my ($data, $server, $witem) = @_;
		my %connected_servers = map { lc($_->{tag}) => $_ } (Irssi::servers());
		for my $srvkey (keys(%address_cache)) {
			unless (exists($connected_servers{$srvkey})) {
				Irssi::print("! Stale server $srvkey");
				++$stales;
			}
		}
		for my $srvkey (keys(%connected_servers)) {
			if (exists($address_cache{$srvkey})) {
				my $server = $connected_servers{$srvkey};
				my $srvhash = $address_cache{$srvkey};
				unless (ref($srvhash) eq "HASH") {
					Irssi::print("!! Non-hash for $srvkey");
					++$errors;
					next;
				}
				my %joined_channels = map { lc($_->{name}) => $_ } ($server->channels());
				for my $chnkey (keys(%$srvhash)) {
					unless (exists($joined_channels{$chnkey})) {
						Irssi::print("! [$srvkey] Stale channel $chnkey");
						++$stales;
					}
				}
				for my $chnkey (keys(%joined_channels)) {
					if (exists($srvhash->{$chnkey})) {
						my $channel = $joined_channels{$chnkey};
						my $chnhash = $srvhash->{$chnkey};
						unless (ref($chnhash) eq "HASH") {
							Irssi::print("!! [$srvkey] Non-hash for $chnkey");
							++$errors;
							next;
						}
						my %nicklist = map { lc($_->{nick}) => $_ } ($channel->nicks());
						for my $nick (keys(%$chnhash)) {
							unless (exists($nicklist{$nick})) {
								Irssi::print("! [$srvkey :: $chnkey] Stale nick $nick");
								++$stales;
							}
						}
						for my $nick (keys(%nicklist)) {
							# Missing entry is ok.
							if (exists($chnhash->{$nick})) {
								my $host = $chnhash->{$nick};
								if (ref($host)) {
									Irssi::print("!! [ $srvkey :: $chnkey ] Entry for $nick is a reference (to $host).");
									++$errors;
									next;
								}
								my $cptr = $nicklist{$nick};
								if (lc($cptr->{host}) ne lc($chnhash->{$nick})) {
									# Not an error - silent hostchanges won't update niclist hosts.
									Irssi::print("[ $srvkey :: $chnkey ] Mismatch on $nick: cached $host, nicklist is " . $cptr->{host});
								}
							}
						}
					} else {
						Irssi::print("!! [$srvkey] Missing cache for $chnkey");
						++$errors;
					}
				}
			} else {
				Irssi::print("!! Missing cache for $srvkey");
				++$errors;
			}
		}
		Irssi::print "Total $stales stale entr" . ($stales == 1 ? "y" : "ies") . " and $errors error" . ($errors == 1 ? "" : "s");
		Irssi::print "You should probably consider clearing the cache" if ($stales > 5 || $errors > 0);
	});
