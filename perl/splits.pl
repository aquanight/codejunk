#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

sub splits($;$);

sub scrub_duplicates(\@)
{
	my ($ary) = @_;
	ref($ary) eq "ARRAY" or die;
	for (my $x = 0; $x < @$ary; ++$x)
	{
		for (my $y = $x + 1; $y < @$ary; ++$y)
		{
			if ($ary->[$y] ~~ $ary->[$x])
			{
				splice @$ary, $y, 1;
				redo;
			}
		}
	}
}

sub splits($;$)
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
	
for my $n ( 1 .. 23 )
{
	my @n = splits($n);
	print "$n -> " . scalar @n . " {";
	foreach my $v (@n)
	{
		print " { " . join(", ", @$v) . " } ";
	}
	print "}\n";
}
