# Scrolling helper script

use strict;
use warnings FATAL => qw(all);

use Irssi;
use Irssi::TextUI;

=head1 Scrolling Script

This script adds a few enhancements to irssi scrollback.

=head2 Usage

Install into irssi script directory, and run /run scrolling. Then see below for commands and settings.

=head2 Commands

=over

=item /scrollback search

Syntax: /scrollback search [-forward] [-rx] <item>

<item> is a word to search through the scrollback. By default, the command searchs upward.

The -forward switch causes the command to search downward instead.

The -rx switch causes <item> to be treated as a regular expression.

=back

=over

=item /scrollback quote

Syntax: /scrollback quote [-rx] [-view] [-#] <item>

Retrieves the line containing <item> and places it into the current input line.

By default, starts at the bottom of the current buffer and stops at the top. -view restricts the search to the currently visible text.
Without -view, if the window is not scrolled all the way down, and a match is found below the current view, and the 'beep_if_scrolled' option
is set, a bell is sounded.

If -rx is used, <item> is a regular expression. If <item> has a capture, the first captured string is inserted, instead of the entire line.

If -# is used, it finds the #th such line. By default # is 1.

=head2 Settings

Several settings are added under the 'scrolling' header:

=over

=item auto_scrolldown

Boolean setting. If set, then the window is scrolled to the bottom when you send a line. Defaults to off.

=item blankline_scroll

Boolean setting. If set, pressing <ENTER> with a blank entry line scrolls the window to the bottom. Default is on.

=item beep_when_scroll

Boolean setting. If set, audible bell plays if you enter a line while scrolled. Default is on.

=item block_while_scrolled

Boolean setting. If set, lines are not accepted while scrolled (no text is sent). Default is on.

=item scrolled_commands

Boolean setting. By default this is off, and commands, and text lines escaped with "/ ", are not affected by the
above settings. If turned on, commands are affected, with the exception of the /scrollback command (so that you can
say '/scrollback end'). Note that in this case, /scrollback must be typed out: aliases will not work.

=back

=cut

our $VERSION = 1;

our %IRSSI = (
	author => qw(aquanight),
	license => 'public domain',
	description => "Enhances irssi scrollback",
	name => 'scrolling'
);

sub sig_send_cmd($$$)
{
	my ($args, $server, $witem) = @_;
	my ($cmdch) = Irssi::settings_get_str("cmdchars");
	if (Irssi::settings_get_bool("scrolled_commands"))
	{
		return if ($args =~ m/^[\Q$cmdch\E]scrollback/); # Don't block the /scrollback command.
	}
	else
	{
		return if ($args =~ m/^[\Q$cmdch\E]/); # Ignore commands. We also allow '/ text' to bypass the lock on texting while scrolled back.
	}
	my $window = Irssi::active_win();
	return unless defined($window); # No window.
	my $view = $window->view();
	return unless defined $view; # No view.
	return if $view->{bottom}; # At bottom do nothing.
	if (Irssi::settings_get_bool("blankline_scroll") && $args eq "")
	{
		# Send empty line == scroll to end
		$window->command("scrollback end");
		Irssi::signal_stop();
		return;
	}
	if (Irssi::settings_get_bool("auto_scrolldown"))
	{
		$window->command("scrollback end");
	}
	if (Irssi::settings_get_bool('beep_when_scrolled'))
	{
		Irssi::signal_emit("beep");
	}
	if (Irssi::settings_get_bool("block_while_scrolled"))
	{
		Irssi::signal_stop();
		return;
	}
}

sub cmd_scrollback_search($$$)
{
	my ($args, $server, $witem) = @_;
	my $window = Irssi::active_win();
	return unless defined $window;
	my $view = $window->view();
	return unless defined $view;
	my $fwd = 0;
	my $userx = 0;
	my ($opts);
	($opts, $args) = Irssi::command_parse_options("scrollback search", $args);
	$opts//return;
	$fwd = exists($opts->{forward});
	$userx = exists($opts->{rx});

	if ($args eq "")
	{
		Irssi::signal_emit("error command", 3); # Not enough params
		return;
	}

	my $pat;
	if ($userx)
	{
		no re qw(eval);
		eval
		{
			$pat = qr/$args/;
		};
		if ($@)
		{
			$@ =~ s/ at .* line \d+\.$//;
			Irssi::print("Error in regular expression: $@", MSGLEVEL_CLIENTERROR);
			return;
		}
	}
	else
	{
		$pat = qr/\Q$args\E/i;
	}

	my $movement = ($fwd ? \&Irssi::TextUI::Line::next : \&Irssi::TextUI::Line::prev);
	my $ln = $view->{startline};

	for ($ln = $movement->($view->{startline}); defined($ln); $ln = $movement->($ln))
	{
		my $txt = $ln->get_text(0);
		if ($txt =~ $pat)
		{
			$view->scroll_line($ln);
			return;
		}
	}
	# Not found.
	Irssi::signal_emit("beep");
}

my $repl_line = undef;
sub cmd_scrollback_quote($$$)
{
	my ($args, $server, $witem) = @_;
	my $window = Irssi::active_win();
	return unless defined $window;
	my $view = $window->view();
	return unless defined $view;
	my $rx = "";
	my $ct = 1;
	my $opts;
	($opts, $args) = Irssi::command_parse_options("scrollback quote" => $args);
	$opts//return;
	$rx = exists($opts->{rx});
	$ct = $opts->{"#"}//1;
	unless (eval {$ct += 0})
	{
		warn "Non numeric item count: $ct";
		return;
	}
	my $pat;
	$args =~ s/\s*$//;
	if ($rx)
	{
		eval
		{
			$pat = qr/$args/;
		};
		if ($@)
		{
			$@ =~ s/ at .* line \d+\.$//;
			Irssi::print("Error in regular expression: $@", MSGLEVEL_CLIENTERROR);
			return;
		}
	}
	else
	{
		$pat = qr/\Q$args\E/i;
	}
	my $ln;
	$repl_line = undef;
	for ($ln = $view->{buffer}->{cur_line}; defined($ln); $ln = $ln->prev())
	{
		my $txt = $ln->get_text(0);
		if ($txt =~ $pat)
		{
			--$ct and next;
			my $inp = $1//$txt;
			$repl_line = $inp;
			last;
		}
	}
	$repl_line//Irssi::signal_emit("beep");
}

sub key_send_line
{
	my ($data, $guidata, $info) = @_;
	$repl_line//return;
	Irssi::gui_input_set($repl_line);
	$repl_line = undef;
}

Irssi::command_bind("scrollback search", \&cmd_scrollback_search);
Irssi::command_set_options("scrollback search" => "forward rx");

Irssi::command_bind("scrollback quote" => \&cmd_scrollback_quote);
Irssi::command_set_options("scrollback quote" => 'rx #');

Irssi::signal_add_last("key send_line" => \&key_send_line);

Irssi::signal_add("send command", \&sig_send_cmd);

Irssi::settings_add_bool(scrolling => "auto_scrolldown", 0); # Auto-scroll to bottom when typing.
Irssi::settings_add_bool(scrolling => "blankline_scroll", 1); # Press <ENTER> on an empty line = scroll down.
Irssi::settings_add_bool(scrolling => 'beep_when_scrolled', 1); # Beep when typing while scrolled
Irssi::settings_add_bool(scrolling => "block_while_scrolled", 1); # Don't send a non-command line when scrolled.
Irssi::settings_add_bool(scrolling => 'scrolled_commands', 0); # Apply scrolling.pl to commands, not just text.
