use strict;
use warnings FATAL => qw(all);

use Irssi;

use CommonStuff;

use POSIX qw(strftime fmod);

our $VERSION = 1;
our %IRSSI = (
	authors => 'aquanight',
	name => 'prettynumerics',
	description => 'Formats output of numerics not handled by irssi',
	license => 'public domain',
);

sub unreal3_stats_tkl_xline {
	my ($server, $args, $nick, $address) = @_;
	my $processIt = 1;
	my %types = (
		G => "G:Line",
		K => "K:Line",
		z => "Z:line",
		Z => "Global Z:Line",
		q => "Q:Line",
		Q => "Global Q:Line",
	);
	my ($target, $type, $banmask, $expire, $set, $setby, $reason);
	if ($server->{version} =~ m/^Unreal3\./ &&
		(($target, $type, $banmask, $expire, $set, $setby, $reason) = ($args =~ m/^([^ ]+) ([^ ]) ([^ ]+) (-?\d+) (-?\d+) ([^ ]+) :(.*)$/))) {
		my ($expire_duration, $expire_time, $set_duration, $set_time);
		my ($setby_nick, $setby_address);
		my $strType = exists($types{$type}) ? $types{$type} : "Unknown $type:Line";
		if ($setby =~ m/^([^ !]+)!([^ @]+@[^ ]+)$/) {
			$setby_nick = $1;
			$setby_address = $2;
		} else {
			$setby_nick = $setby;
			$setby_address = "";
			if (index($setby_nick, ".") < 0) {
				# No dots in name, it's a nick. Without an address.
				# Note that anope sets TKLs like this for AKILLs. For now, we can assume this is true for any unreal3 network until
				# a counterexample is found.
				$strType = "Services-Managed $strType";
			}
		}
		if ($expire == 0) {
			$expire_duration = "never";
			$expire_time = "";
		} else {
			$expire_duration = format_duration($expire, 1);
			$expire_time = strftime(Irssi::settings_get_str("timeformat"), localtime(time + $expire));
		}
		$set_duration = format_duration($set, 1);
		$set_time = strftime(Irssi::settings_get_str("timeformat"), localtime(time - $set));
		# $0 = type, $1 = mask, $2 = expire (1d2h3m4s), $3 = expire (dd-MM-yyyy hh:mm:ss), $4 = set (1d2h3m4s), $5 = set (dd-MM-yyyy hh:mm:ss)
		# $6 = setby (nick), $7 = setby (address), $8 = reason
		$server->printformat("", MSGLEVEL_SNOTES, ($expire == 0 ? "unreal3_perm_xline" : "unreal3_temp_xline"),
				$strType, $banmask, $expire_duration, $expire_time, $set_duration, $set_time, $setby_nick, $setby_address, $reason);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal3_stats_kline {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my %types = (
		K => "K:Line",
		Z => "Z:line",
		E => 'Exception',
	);
	my ($target, $type, $banmask, $reason);
	if (($target, $type, $banmask, $reason) = ($args =~ m/^([^ ]+) ([^ ]+) ([^ ]+) (.*)$/)) {
		my $strType = exists($types{$type}) ? $types{$type} : "Unknown $type:Line";
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal3_conf_xline',
			$strType, $banmask, "never", "", "since server start", "", $server->{real_address}, "", $reason);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub stats_kline {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	if ($server->{version} =~ m/^Unreal3\./) {
		goto &unreal3_stats_kline;
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal3_stats_iline {
	my ($server, $args, $nick, $address) = @_;
	my ($target, $ipmask, $hostmask, $clients, $class, $serverName, $port);
	if (($target, $ipmask, $hostmask, $clients, $class, $serverName, $port) = ($args =~ m/^([^ ]+) I ([^ ]+) \* ([^ ]+) (\d+) ([^ ]+) ([^ ]+) (\d+)$/)) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal3_conf_iline', $ipmask, $hostmask, $clients, $class, $serverName, $port);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal4_stats_iline {
	my ($server, $args, $nick, $address) = @_;
	my ($target, $hostmask, $maxclients, $lineidx, $servername);
	if (($target, $hostmask, $maxclients, $lineidx, $servername) = ($args =~ m/^([^ ]+) I NOMATCH \* ([^ ]+) (\d+) (\d+) ([^ ]+) \*$/)) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal4_conf_iline', $hostmask, $maxclients, $lineidx, $servername);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub stats_iline {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	if ($server->{version} =~ m/^Unreal3\./) {
		goto &unreal3_stats_iline;
	} elsif ($server->{version} =~ m/^(Unreal4\.|InspIRCd-)/) {
		goto &unreal4_stats_iline;
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal3_stats_yline {
	my ($server, $args, $nick, $address) = @_;
	my ($target, $class, $pingfreq, $connfreq, $maxclients, $sendq, $recvq);
	if (($target, $class, $pingfreq, $connfreq, $maxclients, $sendq, $recvq) = ($args =~ m/^([^ ]+) Y ([^ ]+) (\d+) (\d+) (\d+) (\d+) (\d+)$/)) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal3_conf_yline', $class, $pingfreq, $connfreq, $maxclients, $sendq, $recvq);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal4_stats_yline {
	my ($server, $args, $nick, $address) = @_;
	my ($target, $clsidx, $pingfreq, $sendq, $flood, $timeout);
	if (($target, $clsidx, $pingfreq, $sendq, $flood, $timeout) = ($args =~ m/^([^ ]+) Y (\d+) (\d+) 0 (\d+) :(\d+) (\d+)$/)) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal4_conf_yline', $clsidx, $pingfreq, $sendq, $flood, $timeout);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub stats_yline {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	if ($server->{version} =~ m/^Unreal3\./) {
		goto &unreal3_stats_yline;
	} elsif ($server->{version} =~ m/^(Unreal4\.|InspIRCd-)/) {
		goto &unreal4_stats_yline;
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub stats_oline {
	local $_;
	my $processIt = 1;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $operhost, $opernick, $flags, $class);
	if ($server->{version} =~ m/^Unreal3\./ &&
		(($target, $operhost, $opernick, $flags, $class) = ($args =~ m/^([^ ]+) O ([^ ]+) \* ([^ ]+) ([^ ]+) ([^ ]+)$/))) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal3_conf_oline', $opernick, $operhost, $flags, $class);
	} elsif ($server->{version} =~ m/^InspIRCd-/ &&
		(($target, $operhost, $opernick, $class) = ($args =~ m/^([^ ]+) O (.+) \* ([^ ]+) ([^ ]+) 0$/)))
	{
		my @hosts = split / +/, $operhost;
		$server->printformat("", MSGLEVEL_SNOTES, "insp_conf_oline", $opernick, join(", ", @hosts), $class);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub stats_cline {
	local $_;
	my $processIt = 1;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $host, $servername, $port, $class, $flags);
	if ($server->{version} =~ m/^Unreal3\./ &&
		(($target, $host, $servername, $port, $class, $flags) = ($args =~ m/^([^ ]+) C ([^ ]+) \* ([^ ]+) (\d+) ([^ ]+) ([^ ]*)$/))) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal3_conf_cline', $servername, $host, $port, $class, $flags);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub stats_hline {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $hubmask, $servername);
	if (($server->{version} =~ m/^Unreal3\./) &&
		(($target, $hubmask, $servername) = ($args =~ m/^([^ ]+) H ([^ ]+) \* ([^ ]+)$/))) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal3_conf_hline', $servername, $hubmask);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal3_stats_tklexcept {
	local $_;
	my %types = (
		G => "G:Line",
		K => "K:Line",
		z => "Z:line",
		Z => "Global Z:Line",
		q => "Q:Line",
		Q => "Global Q:Line",
		s => "Shun",
	);
	my ($server, $args, $nick, $address) = @_;
	my ($target, $type, $mask);
	if (($server->{version} =~ m/^Unreal3\./) && (($target, $type, $mask) = ($args =~ m/^([^ ]+) ([^ ]) ([^ ]+)$/))) {
		my $strType = exists($types{$type}) ? $types{$type} : "Unknown $type:Line";
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal3_conf_tklexcept', $strType, $mask);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal3_stats_spamfilter {
	local $_;
	my %types = (
		p => 'Private Messages',
		c => 'Channel Messages',
		n => 'Private Notices',
		N => 'Channel Notices',
		P => '/part messages',
		q => '/quit messages',
		d => 'DCC send filenames',
		a => '/away messages',
		t => '/topics',
		u => 'Users (n!u@h:r)',
	);
	my ($server, $args, $nick, $address) = @_;
	my ($target, $targets, $action, $set, $tkl_dur, $reason, $setby, $regex);
	if (($server->{version} =~ m/Unreal3\./) &&
		(($target, $targets, $action, $set, $tkl_dur, $reason, $setby, $regex) = ($args =~ m/^([^ ]+) [fF] ([^ ]+) ([^ ]+) \d+ (\d+) (\d+) ([^ ]+) ([^ ]+) :(.*)$/))) {
		my @targets = split //, $targets;
		my $strTargets = join ", ", @types{@targets};
		$reason =~ s|(_+)|'_' x int(length($1) / 2) . (length($1) % 2 ? " " : "")|eg; # Halve (rounded down) any _, then add a space if there's one left over.
		my ($setby_nick, $setby_address, $set_duration, $set_time, $tkl_duration);
		if ($setby =~ m/^([^ !]+)!([^ @]+@[^ ]+)$/) {
			$setby_nick = $1;
			$setby_address = $2;
		} else {
			$setby_nick = $setby;
			$setby_address = "";
		}
		$set_duration = format_duration($set, 1);
		$set_time = strftime(Irssi::settings_get_str("timeformat"), localtime(time - $set));
		$tkl_duration = format_duration($tkl_dur, 1);
		$server->printformat("", MSGLEVEL_SNOTES, ($action =~ m/^([gkz]|gz)line|shun$/ ? ($tkl_dur == 0 ? 'unreal3_spamf_tklperm' : 'unreal3_spamf_tkl') : 'unreal3_spamf'),
			$strTargets, $action, $set_duration, $set_time, $reason, $setby_nick, $setby_address, $regex, $tkl_duration);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub end_stats {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $type);
	# No version check: this is an RFC standard reply.
	if ((($target, $type) = ($args =~ m/^([^ ]+) ([^ ]) :.*$/))) {
		$server->printformat("", MSGLEVEL_SNOTES, 'end_stats', $type);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal4_module_list {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $loadaddress, $version, $module, $flags);
	if ($server->{version} =~ m/^(InspIRCd-|Unreal4\.)/ &&
		(($target, $loadaddress, $version, $module, $flags) = ($args =~ m/^([^ ]+) :(0x[0-9A-Fa-f]+) (\d+\.\d+\.\d+\.\d+) (.+) \(([^)]+)\)$/))) {
		$server->printformat("", MSGLEVEL_SNOTES, 'unreal4_modlist', $module, $loadaddress, $version, $flags);
	} elsif ($server->{version} =~ m/^(InspIRCd-|Unreal4\.)/ &&
		(($target, $module) = ($args =~ m/^([^ ]+) :(.+)$/))) {
		$server->printformat("", MSGLEVEL_SNOTES, 'insp_modlist_short', $module);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal4_end_modules {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target);
	if ($server->{version} =~ m/^(Unreal4\.|InspIRCd-)/ &&
		(($target) = ($args =~ m/^([^ ]+) :End of MODULES list$/))) {
		$server->printformat("", MSGLEVEL_SNOTES, 'end_of_list', "MODULES");
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub umode_snomasks {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $snomasks);
	if ($server->{version} =~ m/^Unreal3\./ &&
		(($target, $snomasks) = ($args =~ m/^([^ ]+) :Server notice mask \(([^)]+)\)$/))) {
		$server->printformat("", MSGLEVEL_CRAP, "unreal3_snomasks", $snomasks);
	} elsif ($server->{version} =~ m/^(Unreal4\.|InspIRCd-)/ &&
		(($target, $snomasks) = ($args =~ m/^([^ ]+) ([^ ]+) :Server notice mask$/))) {
		$server->printformat("", MSGLEVEL_CRAP, "unreal3_snomasks", $snomasks);
	} else {
		Irssi::signal_emit("default event", $server, $server->parse_special('$H') . " $args", $nick, $address);
	}
	Irssi::signal_stop();
}

sub unreal3_whois_modes {
	local $_;
	my $numeric = Irssi::parse_special('$H');
	my ($server, $args, $nick, $address) = @_;
	my ($target, $whoisnick, $modes, $snomasks);
	if (($target, $whoisnick, $modes, $snomasks) = ($args =~ m/^([^ ]+) ([^ ]+) :is using modes (\+[^ ]*) (?:(\+[^ ]+))?$/)) {
		$snomasks = "" unless defined($snomasks);
		$server->printformat("", MSGLEVEL_CRAP, "unreal3_whois_modes", $whoisnick, $modes, $snomasks);
		Irssi::signal_stop();
		return;
	}
	Irssi::print("[" . $numeric . " $args]");
}

sub insp_chan_badword {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $chan, $filter, $who, $when);
	my $numeric = Irssi::parse_special('$H');
	if ($server->{version} =~ m/^(Unreal4\.|InspIRCd-)/ &&
		(($target, $chan, $filter, $who, $when) = ($args =~ m/^([^ ]+) (#[^ ]+) ([^ ]*) ([^ ]+) (\d+)$/))) {
		my $now = time;
		my $when_duration = format_duration(($now - $when), 1);
		my $when_time = strftime(Irssi::settings_get_str("timeformat"), localtime($when));
		my $strippedfilter;
		($strippedfilter = $filter) =~ s/([\x00-\x1F])/"\cv" . chr(64 + ord($1)) . "\cv"/ge;
		$strippedfilter =~ s/\xFF/"\cv?\cv"/g;
		$server->printformat($chan, MSGLEVEL_CRAP, "insp_chan_badword", $chan, $strippedfilter, $who, $when_duration, $when_time);
		Irssi::signal_stop();
		return;
	}
	Irssi::print("[" . $numeric . " $args]");
}

sub insp_end_badword {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $chan);
	my $numeric = Irssi::parse_special('$H');
	if ($server->{version} =~ m/^(Unreal4\.|InspIRCd-)/ &&
		(($target, $chan) = ($args =~ m/^([^ ]+) ([^ ]+) :End of channel spamfilter list$/))) {
		$server->printformat($chan, MSGLEVEL_CRAP, "insp_end_badword", $chan);
		Irssi::signal_stop();
		return;
	}
	Irssi::print("[" . $numeric . " $args]");
}

sub insp_msg_censored {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my ($target, $chan, $filter);
	my $numeric = Irssi::parse_special('$H');
	if ($server->{version} =~ m/^(Unreal4\.|InspIRCd-)/ &&
		(($target, $chan, $filter) = ($args =~ m/^([^ ]+) ([^ ]+) ([^ ]+) :Your message contained a censored word, and was blocked$/))) {
		my $strippedfilter;
		($strippedfilter = $filter) =~ s/([\x00-\x1F])/"\cv" . chr(64 + ord($1)) . "\cv"/ge;
		$strippedfilter =~ s/\xFF/"\cv?\cv"/g;
		$server->printformat($chan, MSGLEVEL_CRAP, "insp_msg_censored", $chan, $strippedfilter);
		Irssi::signal_stop();
		return;
	}
	Irssi::print("[" . $numeric . " $args]");
}

sub whois_connecting_from {
	local $_;
	my $numeric = Irssi::parse_special('$H');
	my ($server, $args, $nick, $address) = @_;
	my ($target, $whoisnick, $host, $ipaddr);
	if (($target, $whoisnick, $host, $ipaddr) = ($args =~ m/^([^ ]+) ([^ ]+) :is connecting from ([^ ]+)(?: ([^ ]+))?/)) {
		unless (defined($ipaddr) && $ipaddr ne "") {
			$ipaddr = "<unknown>";
		}
		$server->printformat("", MSGLEVEL_CRAP, "whois_connecting_from", $whoisnick, $host, $ipaddr);
		Irssi::signal_stop();
		return;
	}
	Irssi::print("[" . $numeric . " $args]");
}

sub sig_whois_default_event {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	my $numeric = Irssi::parse_special('$H');
	if ($numeric == 379 && $server->{version} =~ m/^Unreal3\./) {
		goto &unreal3_whois_modes;
	} elsif ($numeric == 378 && $server->{version} =~ m/^(?:Unreal[34]\.|InspIRCd)/) {
		goto &whois_connecting_from;
	} elsif ($numeric == 312 || $numeric == 326 || $numeric == 327 || $numeric == 377 || $numeric == 317 || $numeric == 310 || $numeric == 319 || $numeric == 330) {
		return; # Default printing is fine for these (for now).
	} elsif ($numeric == 671 && $server->{version} =~ m/^Unreal[34]\./) {
		# is a secure connection
		return;
	} elsif (($numeric == 307 || $numeric == 320) && $server->{version} =~ m/^(?:Unreal[34]\.|InspIRCd)/) {
		# is a registered nick
		return;
	}
	Irssi::print("[" . $numeric . " $args]");
}

sub insp_jointhrottle {
	local $_;
	my ($server, $args, $nick, $address) = @_;
	if ($server->{version} =~ m/^InspIRCd/)
	{
		my ($target, $chan) =~ ($args =~ m/^([^ ]+) ([^ ]+) :This channel is temporarily unavailabe (\+j). Please try again later./);
		$server->printformat("", MSGLEVEL_CLIENTNOTICE, 'insp_jointhrottle', $chan);
		Irssi::signal_emit("event 437", $server, $args, $nick, $address);
		Irssi::signal_stop();
	}
}

my %format = (
		# $0 = Name of list
		'end_of_list' => 'End of {hilight $0} list',
		# $0 = Module name, $1 = Load address, $2 = Version, $3 = Flags
		'unreal4_modlist' => 'Module {hilight $0} ver {hilight $2} loaded at {hilight $1} {comment $3}',
		# $0 = Module name
		'insp_modlist_short' => 'Module {hilight $0}',
		# $0 = type, $1 = mask, $2 = expire (1d2h3m4s), $3 = expire (dd-MM-yyyy hh:mm:ss), $4 = set (1d2h3m4s), $5 = set (dd-MM-yyyy hh:mm:ss)
		# $6 = setby (nick), $7 = setby (address), $8 = reason
		'unreal3_temp_xline' => '{hilight $0} {ban $1} set $4 ago {comment $5} to expire in $2 {comment on $3} by $6 {nickhost $7} {comment $8}',
		# ($2 = "never", $3 = "")
		'unreal3_perm_xline' => '{hilight Permanent $0} {ban $1} set $4 ago {comment $5} by $6 {nickhost $7} {comment $8}',
		# ($2 = "never", $3 = "", $4 = "since server start", $5 = "", $6 = $server->{name}, $7 = "")
		'unreal3_conf_xline' => '{hilight Permenent $0} {ban $1} {comment $8}',
		# $0 = IP Mask, $1 = Host Mask, $2 = #clients, $3 = class, $4 = server, $5 = port
		'unreal3_conf_iline' => 'Server {server $4} allows clients {comment Class $3} on port {hilight $5} from {nickhost $0} or {nickhost $1} and has $2 clients currently',
		# $0 = Host Mask, $1 = Maximum clients, $2 = index, $3 = server name
		'unreal4_conf_iline' => 'Server {server $3} allows $1 clients {comment Class $2} from {nickhost $0}',
		# $0 = Class, $1 = Ping frequency (seconds), $2 = Connection frequency (seconds), $3 = Max clients, $4 = SendQ Size (bytes), $5 = RecvQ Size (bytes)
		'unreal3_conf_yline' => 'Class {hilight $0} allows $3 clients, pings every $1 seconds, autoconnects servers every $2 seconds, send buffer $4 bytes, recv buffer $5 bytes',
		# $0 = Class Idx, $1 = Ping frequency (seconds), $2 = Send buffer (bytes), $3 = flood trigger, $4 register timeout (seconds)
		'unreal4_conf_yline' => 'Class {hilight $0} pings every $1 seconds, send buffer $2 bytes, flood triggers at $3, registration timeout $4 seconds',
		# $0 = Oper nick, $1 = From host, $2 = Oper flags, $3 = Class
		'unreal3_conf_oline' => 'Operator {nick $0} is allowed from {nickhost $1} with flags {comment $2} {comment Class $3}',
		# $0 = Oper nick, $1 = From host, $2 = Oper class
		'insp_conf_oline' => 'Operator {nick $0} of type {nick $2} is allowed from {nickhost $1}',
		# $0 = Server name, $1 = Address, $2 = Port, $3 = Class, $4 = Flags
		'unreal3_conf_cline' => 'Links to server {server $0} from {nickhost $1} port {hilight $2} class {hilight $3} {comment Flags: $4}',
		# $0 = Server name, $1 = Hub mask
		'unreal3_conf_hline' => 'Server {server $0} is allowed to link servers matching {nickhost $1}',
		# $0 = Type string, $1 = Mask
		'unreal3_conf_tklexcept' => '{hilight Permanent Exception from $0} {ban $1}',
		# $0 = Spamfilter Targets, $1 = Spamfilter action, $2 = Spamfilter set (1d2h3m4s), $3 = Spamfilter set (dd-MM-yyyy hh:mm:ss), $4 = Reason, $5 = setby (nick),
		# $6 = setby (address), $7 = regex
		'unreal3_spamf' => 'Spamfiltering {hilight $0} matching {comment $7} set $2 ago {comment $3} by $5 {nickhost $6}, set to {hilight $1} {comment $4}',
		# .. $8 = tkl duration (1d2h3m4s)
		'unreal3_spamf_tkl' => 'Spamfiltering {hilight $0} matching {comment $7} set $2 ago {comment $3} by $5 {nickhost $6}, set to {hilight $1 for $8} {comment $4}',
		# .. $8 = "0s"
		'unreal3_spamf_tklperm' => 'Spamfiltering {hilight $0} matching {comment $7} set $2 ago {comment $3} by $5 {nickhost $6}, set to {hilight $1 forever} {comment $4}',
		# $0 = Stats type
		'end_stats' => 'End of {hilight STATS $0}',
		# $0 = Snomasks
		'unreal3_snomasks' => 'Your snomasks are {mode $0}',
		# $1 = modes, $2 = snomasks
		'unreal3_whois_modes' => '{whois modes $1}%:{whois snomasks $2}',
		# $1 = host, $2 = ip
		'whois_connecting_from' => '{whois realhost $1}%:{whois realip $2}',
		# $0 = channel, $1 = word, $2 = who, $3 = when (1d2h3m4s), $4 = when (dd-MM-yyyy hh:mm:ss)
		'insp_chan_badword' => '{channel $0} filter {ban $1} by $2, $3 ago {comment $4}',
		# $0 = channel
		'insp_end_badword' => '{channel $0} End of filter list',
		# $0 = channel, $1 = badword
		'insp_msg_censored' => 'Cannot send a message containing {ban $1} to {channel $0}',
		# $0 = channel name
		'insp_jointhrottle' => 'Cannot join {channel $0} - it is unavailable',
);

sub sig_default_event {
	my ($server, $data, $nick, $address) = @_;
	return unless defined($data);
	if (defined($server)) {
		$server->print("", ($nick ne $server->{real_address} ? "[$nick] [" : "[") . $data . "]", MSGLEVEL_CRAP);
	} else {
		Irssi::print($data, MSGLEVEL_CRAP);
	}
	Irssi::signal_stop();
}

Irssi::theme_register([%format]);

Irssi::settings_add_str("prettynumerics", "timeformat", "%d %b %Y %H:%M:%S %Z");

Irssi::signal_add("event 216", \&stats_kline); # ban user {} and ban ip {} go here, also except ban {}
Irssi::signal_add("event 223", \&unreal3_stats_tkl_xline); # TKL bans of all kinds (K, z, G, G-Z) go here
Irssi::signal_add("event 217", \&unreal3_stats_tkl_xline); # q and Q TKL bans
Irssi::signal_add("event 215", \&stats_iline); # allow user {}
Irssi::signal_add("event 218", \&stats_yline); # class {}
Irssi::signal_add("event 243", \&stats_oline); # oper {}
Irssi::signal_add("event 213", \&stats_cline); # link {}
Irssi::signal_add("event 244", \&stats_hline); # link::hub
Irssi::signal_add("event 230", \&unreal3_stats_tklexcept); # except tkl {}
Irssi::signal_add("event 229", \&unreal3_stats_spamfilter); # spamfilter {}
Irssi::signal_add("event 219", \&end_stats);
Irssi::signal_add("event 008", \&umode_snomasks);
Irssi::signal_add("event 900", \&unreal4_module_list);
Irssi::signal_add("event 901", \&unreal4_end_modules);
Irssi::signal_add("event 379", \&unreal3_whois_modes);
Irssi::signal_add("event 378", \&whois_connecting_from);
Irssi::signal_add("event 941", \&insp_chan_badword);
Irssi::signal_add("event 940", \&insp_end_badword);
Irssi::signal_add("event 936", \&insp_msg_censored);
Irssi::signal_add("event 609", \&insp_jointhrottle);
Irssi::signal_add("whois default event", \&sig_whois_default_event);

Irssi::signal_add("default event", \&sig_default_event);

