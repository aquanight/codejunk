use strict;
use warnings FATAL => qw(all);

use Irssi;

use Term::Cap ();
use POSIX ();

our $VERSION = 1;
our %IRSSI = (
	authors => 'aquanight',
	name => 'xterm',
	description => 'Makes use of x-term title bar',
	license => 'public domain',
);

our $starttitle; # Termcap ts
our $endtitle; # Termcap fs

# Sigh. Someone has something against putting hardstatus info in termcap for screen.

sub init_titlestuff() {
	if ($ENV{TERM} eq 'screen') {
		$starttitle = "\e_";
		$endtitle = "\e\\";
	} else {
		init_termcap();
	}
}

sub init_termcap() {
	my $termios = new POSIX::Termios;
	$termios->getattr;
	my $terminal = Tgetent Term::Cap { TERM => undef, OSPEED => $termios->getospeed };
	$terminal->Trequire qw(hs ts fs); # hs = has status, ts = to status, fs = from status
	$starttitle = $terminal->Tputs("ts", 1, undef);
	$endtitle = $terminal->Tputs("fs", 1, undef);
}

sub set_title($) {
	my ($title) = @_;
	my $str = $starttitle . $title . $endtitle;
	print STDERR $str;
}

sub cmd_title {
	my ($data, $server, $witem) = @_;
	set_title($data);
}

sub build_title
{
	my $ref = Irssi::windows_refnum_last();
	my @active = ();
	my $title = "";
	while ($ref > 0)
	{
		my $win = Irssi::window_find_refnum($ref);
		if (defined($win))
		{
			if ($win->{data_level} >= Irssi::settings_get_int("title_activity_level"))
			{
				unshift @active, $ref;
			}
		}
		$ref = Irssi::window_refnum_prev($ref, 0);
	}
	if (scalar(@active) > 0)
	{
		$title = '[A:' . join(",",@active) . "] ";
	}
	$title .= Irssi::parse_special(Irssi::settings_get_str("maintitle"));
	set_title $title;
}

sub sig_window_activity
{
	my ($win, $oldlvl) = @_;
	build_title();
}

sub sig_window_changed
{
	my ($win, $prev) = @_;
	build_title();
}

sub sig_window_item_changed
{
	my ($win, $witem) = @_;
	build_title();
}

init_titlestuff();

#Irssi::command_bind('title', \&cmd_title);

Irssi::settings_add_str("xterm", "maintitle", 'Irssi $J');
Irssi::settings_add_int("xterm", "title_activity_level", 2);
Irssi::signal_add_last("window activity", \&sig_window_activity);
Irssi::signal_add_last("window changed", \&sig_window_changed);
Irssi::signal_add_last("window item changed", \&sig_window_item_changed);

build_title();

if ($ENV{TERM} eq 'screen') {
	# Bonus for screen: we can set the window title (seen in, eg CTRL+A,") too.
	print STDERR "\ekIrssi\e\\";
}
