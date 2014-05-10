use 5.16.0;

use strict;
use warnings FATAL => 'all';

use Irssi;

use Time::HiRes ();

our $VERSION = 1;

our %IRSSI = (
	author => q(aquanight),
	license => 'public domain',
	description => "Provides hexadecimal timestamp in \$hextime expando",
	name => 'hextimestamp'
);

my ($now,$nowus) = Time::HiRes::gettimeofday();

sub expando_hextime
{
	my ($server, $item) = @_;
	my (@lcltime) = localtime $now;
	my $secday = $lcltime[0] + ($lcltime[1] * 60) + ($lcltime[2] * 3600);
	my $fracday = ($secday + ($nowus / 1000000)) / 86400;
	my $res = "";
	for (my $bit = 1; $bit <= 5; ++$bit)
	{
		my $what;
		$what = ($fracday * (16 ** $bit)) % 16;
		$res .= sprintf("%01X", $what);
	}
	return $res;
}

sub sig_hextimer
{
	# Check if $hextime has changed.
	my ($_now,$_nowus) = Time::HiRes::gettimeofday();
	if ($_now != $now || $_nowus != $nowus)
	{
		Irssi::signal_emit("hextime changed");
		$now = $_now;
		$nowus = $_nowus;
	}
}

Irssi::signal_register({
		"hextime changed" => []
	}
);

Irssi::expando_create("hextime" => \&expando_hextime, {
	'hextime changed' => 'none'
});

Irssi::timeout_add(100 => \&sig_hextimer, undef);
