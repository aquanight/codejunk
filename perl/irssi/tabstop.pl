use strict;
use warnings FATAL => 'all';

use Irssi;
use Irssi::TextUI;

our %IRSSI = (
	name => 'tabstop',
	authors => qw[aquanight],
	description => 'expand tabs on print, rather than nasty inverted-I',
	license => 'public domain'
);

our $VERSION = 1;

#sub space_out($$)
#{
#	my ($txt, $ts) = @_;
#	return $txt . (" " x ($ts - length($txt)));
#}

sub soft_tabs($$\$)
{
	my ($ts, $pos, $state) = @_;
#	Irssi::print("Position at $pos, cursor at " . ($pos + $$state));
	ref($state) eq "SCALAR" or die;
	my $spc = $ts - ($pos + $$state) % $ts;
	$$state += ($spc - 1);
	return " " x $spc;
}

our $_state; # MUST be 'our' for 'local' to work.
sub sig_print_text($$)
{
	my ($dst, $txt, $stripped) = @_;

	my $rewrite = 0;

	if ($txt =~ /\t/)
	{
		# ABSOLUTELY MUST NOT EVER PRINT A TAB HERE!!!
		my $ts = Irssi::settings_get_int('tabstop_interval');
		# 0 or less = disabled.
		return if ($ts < 1);
		if (Irssi::settings_get_bool("tabstop_fixedtabs"))
		{
			my $spc = ' ' x $ts;
			$txt =~ s/\t/$spc/g;
		}
		else
		{
			# Ugh, columning.
			# One problem is that tab expansion can result in the line getting wrapped oddly, since
			# I cannot be sure if 'print text' is pre-window wrapping or not.
			# I shall settle for columnizing the "virtual" line only.
			#my $spc = $ts - 1;

			#$txt =~ s[((?:[^t]{$spc})*[^\t]{0,$spc})\t]{space_out($1, $ts)}ge;
			my $softadj = 0; # Amount of spacing added.
			$txt =~ s/\t/soft_tabs($ts, pos($txt), $softadj)/ge;
		}
		$rewrite = 1;
	}

	if ($txt =~ /\cH/)
	{
		# Must handle UTF-8 characters correctly.
		if (Irssi::settings_get_str("term_charset") eq "utf-8")
		{
			utf8::decode($txt);
		}
		$_state = 0;
		$txt =~ s/((?:\cB|\c_|\cV|\cO|\cF|\cC\d*,\d*|\cD[abcdeghi]|\cD..|\e\[[[:digit:];]*m)*(?:.(?{local $_state = $_state + 1}))+)(??{sprintf("%c{%d}", 8, $_state)})/sprintf("\cDg\cD4\/%s\cDg", Irssi::strip_codes($1))/ge;
		$rewrite = 1;
		if (Irssi::settings_get_str("term_charset") eq "utf-8")
		{
			utf8::encode($txt);
		}
	}

	if ($rewrite)
	{
		Irssi::signal_emit("print text", $dst, $txt, $stripped);
		Irssi::signal_stop();
	}
}

Irssi::settings_add_bool(tabstop => "tabstop_fixedtabs", 0); # 1 -> tabs are always the same length.
Irssi::settings_add_int(tabstop => "tabstop_interval", 9); # Length of fixed tab, or interval of tab stops.

Irssi::signal_add("print text" => \&sig_print_text);
