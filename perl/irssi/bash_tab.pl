use strict;
use warnings FATAL => qw(all);

BEGIN
{
	__PACKAGE__ eq "Irssi::Script::bash_tab" or die "This is an irssi extension script.\n";
}

use Irssi;
use Irssi::TextUI;

our $VERSION = 1;
our %IRSSI = (
	authors => qw(aquanight),
	name    => q[bash_tab],
	description => q[Provides bash-style tab completion, replacing the rotated-list style used by irssi.],
	license => q[public domain],
	);

our @last_result;

# To make this work we must replace the binding output from word_completion[_backwards] and erase_completion
# We must reimplement the following functions:
# key_completion from src/fe-text/gui-readline.c
# word_complete from src/fe-common/core/completion.c
# get_word_at from src/fe-common/core/completion.c
# And override the binding functions named above

sub bell()
{
	Irssi::command("beep");
}

my $previous;
my $prevspace;
my $prevline;
my $prevpos;
# Line and position to restore when erase_completion key is pressed.
# This is not the same as the "previous" line and position as we change those
# when we auto-expand completions with common stems.
my $erase_line;
my $erase_pos;

sub splice_word($$)
{
	my ($str, $pos) = @_;
	# Get previous word is pos is at a space.
	--$pos while substr($str, $pos, 1) =~ m/^[ ,]$/;
	# Irssi's get_word_at used the following logic:
	# Seperators are either space or comma.
	# Backup start to the first nonseperator.
	# Extend end to the last nonseperator, then to the last comma.
	# We return the word, but also the line portion before and after it, with the seperators removed.
	my ($pre, $word, $post) = ($str =~ m/^(.{0,$pos}[ ,])?([^ ,]*,*)(.*)?$/);
	$pre = "" unless defined($pre);
	$post = "" unless defined($post);
	return ($pre, $word, $post);
}

sub longest_common_stem(@)
{
	my (@words) = @_;
	scalar(@words) < 2 and return $words[0];
	grep {/\n/} @words and die "No newlines allowed";
	my $content = join "\n", @words;
	# What this regex is doing is we join the words into a newline-seperated string. As this is being used for irssi tab completion
	# newlines should never occur in the strings proper. (We assert this above.)
	# We capture the leading portion of the first word, then require that every word thereafter starts with the same leading portion.
	# The use of greedy captures ensures we get the longest possible result.
	my ($stem) = $content =~ /^([^\n]*)[^\n]*(\n\1[^\n]*)+$/i;
	# An undef meant the regex did not match, but it should never fail to match because the capture group can match a zero-length string.
	# So if it fails then something else went horribly wrong.
	$stem//die "Failed to find a common stem";
	# In the case of completion_strict = OFF we may get a case where f<tab> produces a list such as [foo] _foo_ ]foo[ and foo
	# In that situation, longest_common_stem will return an empty string. It is for now left up to complete_word to deal with this situation.
	return $stem;
}

sub complete_word ($$\$$$)
{
	my ($window, $text, $pos, $erase, $backward) = @_;
	my $continue = defined($previous) && ($prevline eq $text) && ($$pos == $prevpos);
	if (!$continue)
	{
		# Invalidate the crap.
		$previous = undef;
		$prevline = undef;
		$prevpos = undef;
		$erase_line = undef;
		$erase_pos = undef;
	}
	if ($erase)
	{
		if (defined($erase_line) && defined($erase_pos))
		{
			# It seems the purpose of erase_completion is not to "undo" a tab completion as I originally thought it did.
			# Instead it removes tab-completed items from the list of things to be completed where permitted. For example
			# in /msg <nick>[TAB] erase_completion removes nicks from the messsaging history.
			# I don't personally use this feature. So instead I shall replace it with what I thought erase_completion
			# was doing: undo a tab completion.
			$$pos = $erase_pos;
			my $res = $erase_line;
			$previous = undef;
			$prevline = undef;
			$prevpos = undef;
			$erase_line = undef;
			$erase_pos = undef;
			return $res;
		}
		else
		{
			bell();
			return undef;
		}
	}
	else
	{
		if ($continue)
		{
			my $longest = 1 + (sort {$b<=>$a} map {length($_)} @$previous)[0];
			my $width = $window->{width} - Irssi::format_get_length("timestamp");
			my $ipl = ($width / $longest);
			$ipl = 1 if $ipl < 1;
			if ($ipl == 1)
			{
				$window->print($_, MSGLEVEL_CLIENTCRAP) for @$previous;
			}
			else
			{
				for (my $ix = 0; $ix < scalar(@$previous); $ix += $ipl)
				{
					my @items;
					if ($ix + $ipl - 1 > $#$previous)
					{
						@items = @{$previous}[$ix .. $#$previous];
					}
					else
					{
						@items = @{$previous}[$ix .. ($ix + $ipl - 1)];
					}
					my $row = join "", map { sprintf("%-*s", $longest, $_) } @items;
					$window->print($row, MSGLEVEL_CLIENTCRAP);
				}
			}
			return undef;
		}
		else
		{
			my ($before, $word, $after) = splice_word($text, $$pos);
			my ($linestart) = ($before =~ m/^(.*?)[ ,]*$/);
			my $want_space = 1;
			my $complist = [];
			Irssi::signal_emit("complete word", $complist, $window, $word, $linestart, \$want_space);
			if (@$complist < 1)
			{
				# No results.
				bell();
				return undef;
			}
			# Save the current condition to restore with erase_completion.
			$erase_line = $text;
			$erase_pos = $$pos;
			if (@$complist == 1)
			{
				my $result = $complist->[0];
				$result .= " " if ($want_space);
				$$pos = length($before) + length($result);
				return "${before}${result}${after}";
			}
			else
			{
				# Multiple results.
				bell();
				$previous = $complist;
				my $result = longest_common_stem(@$complist);
				if (length $result < length $word) { $result = $word; } # Don't accept a stem shorter than the original input.
				# IGNORE want_space as this is not a full completion.
				$prevline = $before . $result . $after;
				$prevpos = $$pos = length($before) + length($result);
				return "${before}${result}${after}";
			}
		}
	}
}

sub key_complete ($$$$$)
{
	my ($data, $guidata, $info, $reverse, $erase) = @_;

	my $window = Irssi::active_win();

	my ($txt, $pos);
	$txt = Irssi::parse_special('$L'); # Why no gui_input_get ?!
	$pos = Irssi::gui_input_get_pos();

	my $res = complete_word($window, $txt, $pos, $erase, $reverse);
	if (defined($res))
	{
		Irssi::gui_input_set($res);
		Irssi::gui_input_set_pos($pos);
	}

	Irssi::signal_stop();
}

sub sig_key_complete
{
	my ($data, $guidata, $info) = @_;
	key_complete($data, $guidata, $info, 0, 0);
}

sub sig_key_complete_backward
{
	my ($data, $guidata, $info) = @_;
	key_complete($data, $guidata, $info, 1, 0);
}

sub sig_key_complete_erase
{
	my ($data, $guidata, $info) = @_;
	key_complete($data, $guidata, $info, 0, 1);
}

Irssi::signal_add_first("key word_completion", \&sig_key_complete);
Irssi::signal_add_first("key word_completion_backward", \&sig_key_complete_backward);
Irssi::signal_add_first("key erase_completion", \&sig_key_complete_erase);

1;
