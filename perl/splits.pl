#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

sub splits;

sub set_compare($$)
{
	my ($seta, $setb) = @_;
	# We should not get undef sets
	$seta//die;
	$setb//die;
	for (my $ix = 0; ; ++$ix)
	{
		my ($ia, $ib) = ($seta->[$ix], $setb->[$ix]);
		unless (defined($ia))
		{
			return defined($ib) ? -1 : 0;
		}
		return 1 unless defined $ib;
		return ($ia <=> $ib) if ($ia <=> $ib);
	}
}

sub scrub_duplicates(\@)
{
	my ($ary) = @_;
	ref($ary) eq "ARRAY" or die;
	my @tmp;
	@tmp = sort set_compare @$ary;
	my @uniq = ($tmp[0]);
	for (my $x = 1; $x <= $#tmp; ++$x)
	{
		next unless set_compare($tmp[$x - 1], $tmp[$x]);
		push @uniq, $tmp[$x];
	}
	@$ary = @uniq;
}

sub splits
{
	my ($n, $minimum) = @_;
	my @results;
	$minimum //= 1;
	my $nstr = '1' x $n;
	for my $x ( $minimum .. $n )
	{
		if ($n % $x == 0)
		{
			push @results, [ $x ];
		}
		for my $y ( ($x + 1) .. ($n - $x) )
		{
			next unless $nstr =~ m/^(1{$x})+(1{$y})+$/;
			my @x = splits($y, $x + 1);
			unshift @$_, $x foreach @x;
			push @results, @x;
		}
	}
	scrub_duplicates @results;
	return @results;
}
	
for my $n ( 1 .. 30 )
{
	my @n = splits($n);
	print "$n -> " . scalar @n ;#. " {";
#	foreach my $v (@n)
#	{
#		print " { " . join(", ", @$v) . " } ";
#	}
#	print "}\n";
	print "\n";
}
