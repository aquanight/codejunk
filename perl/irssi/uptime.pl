use strict;
use warnings FATAL => qw(all);

use Irssi;
use CommonStuff;

our $VERSION = 1;

our %IRSSI = (
	authors => qw(aquanight),
	name => 'uptime',
	description => 'Better /uptime command, reports on server, irssi, and local system',
	license => 'public domain',
);

sub cmd_uptime
{
	my ($data, $server, $witem) = @_;
	my $curtime = time;

	# System uptime
	if ($^O eq "linux")
	{
		my $fh;
		my $line;
		if (open $fh, "<", "/proc/uptime")
		{
			$line = <$fh>;
			my ($up, $idle) = split / /, $line;
			$idle/=2;
			close $fh;
			Irssi::print sprintf("System up %s, idle %s [%.2f%%]", format_duration($up), format_duration($idle), ($idle * 100 / $up)), MSGLEVEL_CLIENTNOTICE;
		}
		else
		{
			$fh = undef;
			Irssi::print "Unable to retrieve system uptime: $!", MSGLEVEL_CLIENTERROR;
		}
		if (open $fh, "<", "/proc/loadavg")
		{
			$line = <$fh>;
			my ($l1, $l5, $l15) = split / /, $line;
			close $fh;
			Irssi::print sprintf("Load: 1min=%.2f, 5min=%.2f, 15min=%.2f", $l1, $l5, $l15);
		}
		else
		{
			$fh = undef;
			Irssi::print "Unable to retrieve load averages: $!", MSGLEVEL_CLIENTERROR;
		}
	}
	my $irsboot = Irssi::parse_special("\$F");
	Irssi::print sprintf("Irssi up %s", format_duration($curtime - $irsboot)), MSGLEVEL_CLIENTNOTICE;
	foreach my $srv (Irssi::servers())
	{
		$srv->{connected} or next;
		my $conup = $srv->{real_connect_time};
		$srv->print("", sprintf("Server connected for %s", format_duration($curtime - $conup)), MSGLEVEL_CLIENTNOTICE);
	}
	Irssi::signal_stop();
}

Irssi::command_bind("uptime", \&cmd_uptime);

