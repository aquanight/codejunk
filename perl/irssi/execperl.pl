use strict;
use warnings FATAL => qw(all);
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI);

use CommonStuff;

#use Cwd;
use POSIX qw(strftime);

{ package Irssi::Nick; } # Keeps trying to look for this package but for some reason it doesn't get loaded.

$VERSION = '1.00';
%IRSSI = (
	authors => 'aquanight',
	contact => 'aquanight@gmail.com',
	name => 'execperl',
	description => 'Command-line access to perl from irssi.',
	license => 'public domain'
	);

sub hash_sort (\%) {
	my ($hash) = @_;
	return [sort {$a cmp $b} keys %$hash];
}

# Evalutes the code provided by the user in list context.
sub eval_perl {
	my ($data, $server, $witem) = @_;
	my %switches;
	while ($data =~ m/^(?:-(\S+)) (.*)$/)
	{
		$data = $2;
		last if ($1 eq '-');
		$switches{$1} = 1;
	}
	my @result;
	{
		# Load in autovars:
		# <punctuation autovars not supported, blame Perl>
		# $A : Away msg text
		# $B : Body of last MSG
		# $C : Current channel ($witem->{name}, if and only if $witem is a channel).
		# $D : Last NOTIFY signon
		# $E : idle time
		# $F : time client wass started, $time() format
		# $H : Current server numeric being processed
		# $I : Last INVITE
		# $J : client version text string
		# $K : Current value of CMDCHARS
		# $k : First char of CMDCHARS
		# $L : Current contents of input line
		# $M : Modes of $C
		# $N : Current nick
		# $O : Value of STATUS_OPER if $N->is_oper
		# $P : If chanop in $C, '@'
		# $Q : Nickname in query
		# $R : Server version
		# $S : Server name
		# $T : target of current input
		# $U : Cutbuffer
		# $V : client release date
		# $W : current working directory
		# $X : userhost $N
		# $Y : REALNAME
		# $Z : time of day in timestamp_format
		my $window = Irssi::active_win();
		my $A = ($server && $server->{usermode_away} ? $server->{away_reason} : "");
		my $B = Irssi::parse_special('$B');
		my $C = ($witem && $witem->{type} eq "CHANNEL" ? $witem->{name} : "");
		my $D = Irssi::parse_special('$D');
		my $E = Irssi::parse_special('$E');
		my $F = Irssi::parse_special('$F');
		my $H = Irssi::parse_special('$H');
		my $I = ($server ? $server->{last_invite} : "");
		my $J = Irssi::parse_special('$J');
		my $K = Irssi::settings_get_str("CMDCHARS");
		my $k = substr($K, 0, 1);
		my $L = Irssi::parse_special('$L');
		my $M = ($witem && $witem->{type} eq "CHANNEL" ? $witem->{mode} : "");
		my $N = ($server ? $server->{nick} : Irssi::settings_get_str("nick"));
		my $O = ($server && $server->{server_operator} ? Irssi::settings_get_str("STATUS_OPER") : "");
		my $P = ($witem && $witem->{type} eq "CHANNEL" && $witem->{ownnick}->{op} ? "@" : "");
		my $Q = ($witem && $witem->{type} eq "QUERY" ? $witem->{name} : "");
		my $R = ($server ? $server->{version} : "");
		my $S = ($server ? $server->{real_address} : "");
		my $T = ($witem ? $witem->{name} : "");
		my $U = Irssi::parse_special('$U');
		my ($V, $versiontime) = (Irssi::version() =~ m/^(\d+)\.(\d+)$/);
		my $W = Irssi::parse_special('$W');
		my $X = ($server ? $server->{userhost} : "");
		my $Y = ($server ? $server->{realname} : Irssi::settings_get_str("real_name"));
		my $Z = strftime(Irssi::settings_get_str("timestamp_format"), localtime);
		my $sysname = Irssi::parse_special('$sysname');
		my $sysrelease = Irssi::parse_special('$sysrelease');
		my $sysarch = Irssi::parse_special('$sysarch');
		my $topic = ($witem && $witem->{type} eq "CHANNEL" ? $witem->{topic} : "");
		my $usermode = ($server ? $server->{usermode} : "");
		my $cumode = Irssi::parse_special('$cumode');
		my $cumode_space = ($cumode eq "" ? " " : $cumode);
		my $tag = ($server ? $server->{tag} : "");
		my $chatnet = ($server ? $server->{chatnet} : "");
		my $winref = $window->{refnum};
		my $winname = $window->{name};
		my $itemname = ($witem ? $witem->{visible_name} : "");
		# Now some handy autovars:
		# %nicks - If $witem is a channel, has all the nicks in the channel, hashed by nick.
		my %nicks;
		if ($witem && $witem->{type} eq "CHANNEL") {
			for my $cptr ($witem->nicks()) {
				$nicks{$cptr->{nick}} = $cptr;
			}
		}
		@result = eval $data;
	}
	if ($@) {
		$window->print("Script error; $@", MSGLEVEL_CLIENTNOTICE);
		return;
	}
	return if $switches{noprint};
	use Data::Dumper;

	local $Data::Dumper::Purity = 0; # Recursively process references I guess.
	local $Data::Dumper::Varname = "VALUE";
	local $Data::Dumper::Useqq = 1; # Use "" and quote stuff. Slow.
	local $Data::Dumper::Quotekeys = 1;
	local $Data::Dumper::Deparse = 1;
	local $Data::Dumper::Sortkeys = \&hash_sort;

	if (scalar(@result) < 1)
	{
		$window->print("Expression returned no value.", MSGLEVEL_CLIENTNOTICE);
	}
	elsif (scalar(@result) == 1)
	{
		$window->print("Expression returned single value:", MSGLEVEL_CLIENTNOTICE);
		eval {
			$window->print(Data::Dumper->Dump([$result[0]], ["result"]), MSGLEVEL_CLIENTNOTICE);
		};
		if ($@) {
			my $x = $result[0];
			if (ref($x)) {
				$window->print(sprintf("Dump failed of value [%s]: %s", "$x", $@), MSGLEVEL_CLIENTNOTICE);
			} else {
				$window->print(sprintf("Dump failed of value: %s", $@), MSGLEVEL_CLIENTNOTICE);
			}
		}
		$window->print("---", MSGLEVEL_CLIENTNOTICE);
	}
	else
	{
		$window->print(sprintf("Expression returned %d values:", scalar(@result)), MSGLEVEL_CLIENTNOTICE);
		my $str = "";
		for my $idx (0..$#result) {
			eval {
				$str .= Data::Dumper->Dump([$result[$idx]], ["result[$idx]"]);
			};
			if ($@) {
				my $x = $result[0];
				if (ref($x)) {
					$str .= sprintf("Dump failed of value %d [%s]: %s\n", $idx, "$x", $@);
				} else {
					$str .= sprintf("Dump failed of value %d: %s\n", $idx, $@);
				}
			}
		}
		$window->print($str, MSGLEVEL_CLIENTNOTICE);
		$window->print("---", MSGLEVEL_CLIENTNOTICE);
	}
}

Irssi::command_bind('evalperl', 'eval_perl');
