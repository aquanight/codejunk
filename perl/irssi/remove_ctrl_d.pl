use strict;
use warnings FATAL => 'all';

use Irssi;

our $VERSION = 1;

our %IRSSI = (
	author => qw(aquanight),
	license => 'public domain',
	description => "Converts CTRL+D formatting codes into standard IRC coloring for incoming server messages, closes a remote bypass to hide_colors/hide_text_styles",
	name => 'remove_ctrl_d'
);

sub make_color($$)
{
	my ($fg, $bg) = @_;
	if ($fg eq '.') {
		return sprintf("\3%d", ord($bg) - 31);
	}
	elsif ($fg eq '-') {
		return sprintf("\3%d", ord($bg) + 49);
	}
	elsif ($fg eq ',') {
		return sprintf("\3%d", ord($bg) + 129);
	}
	elsif ($fg eq '+') {
		return sprintf("\3,%d", ord($bg) - 31);
	}
	elsif ($fg eq "'") {
		return sprintf("\3,%d", ord($bg) + 49);
	}
	elsif ($fg eq '&') {
		return sprintf("\3,%d", ord($bg) + 129);
	}

	$fg = ord($fg) - ord('0');
	$bg = ord($bg) - ord('0');
	if ($fg >= 0 && $fg <= 15)
	{
		if ($bg >= 0 && $bg <= 15)
		{
			return sprintf("\3%d,%d", $fg, $bg);
		}
		else
		{
			return sprintf("\3%d", $fg);
		}
	}
	else
	{
		if ($bg >= 0 && $bg <= 15)
		{
			return sprintf("\3,%d", $fg, $bg);
		}
		else
		{
			return "";
		}
	}
}

sub sig_remove_ctrl_d($$)
{
	my ($serv, $data, $nick, $addr) = @_;

	my $rewrite = 0;

	if ($data =~ /\x04/)
	{
		$data =~ s/\x04a/\cF/g; # Replace FORMAT_STYLE_BLINK with CTRL+F
		$data =~ s/\x04b/\c_/g; # Replace FORMAT_STYLE_UNDERLINE with CTRL+_
		$data =~ s/\x04c/\cB/g; # Replace FORMAT_STYLE_BOLD with CTRL+B
		$data =~ s/\x04d/\cV/g; # Replace FORMAT_STYLE_REVERSE with CTRL+V
		$data =~ s/\x04e//g; # Remove FORMAT_STYLE_INDENT
		$data =~ s/\x04g/\cO/g; # Replace FORMAT_STYLE_DEFAULTS with CTRL+O
		$data =~ s/\x04h//g; # Remove FORMAT_STYLE_CLRTOEOL
		$data =~ s/\x04i//g; # Remove FORMAT_STYLE_MONOSPACE
		$data =~ s/\x04#....//g; # Remove 24-bit colors
		$data =~ s/\x04(.)(.)/make_color($1, $2)/ge; # Convert color coding.
		$data =~ s/\x04//g; # Remove any remaining CTRL+D markers (malformed code, etc).
		$rewrite = 1;
	}

	if ($rewrite)
	{
		# Stop the signal and re-emit it.
		Irssi::signal_stop();
		Irssi::signal_emit("server event", $serv, $data, $nick, $addr);
	}
}

Irssi::signal_add_first("server event", \&sig_remove_ctrl_d);
