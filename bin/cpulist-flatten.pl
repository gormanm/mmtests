#!/usr/bin/perl
use strict;

sub parse_kernel_cpu_ranges($) {
        my $spans = $_[0];
        my @cpus;

        chomp($spans);
        foreach my $span (split(/,/, $spans)) {
                my ($from, $to) = split(/-/, $span);
                $to = $from if (! defined $to);
                for (my $i = $from; $i <= $to; $i++) {
                        push @cpus, $i;
                }
        }
        @cpus = sort { $a <=> $b } @cpus;
        return \@cpus;
}

foreach my $cpu (@{parse_kernel_cpu_ranges($ARGV[0])}) {
	print "$cpu\n";
}
