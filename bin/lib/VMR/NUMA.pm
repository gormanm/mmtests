#
# NUMA.pm
#
package VMR::NUMA;
require Exporter;
use vars qw (@ISA @EXPORT);
use VMR::Stat;
use VMR::Report;
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&numa_memory_balance);

# This takes pairs of values (currentUsage, memorySize). Each pair represents
# a memory node and the return value is the memory balance. The objective is
# to measure how balanced NUMA memory usage is.
#
# Node utilisation is
#
# Nu = U(n) / S(n)
# where Un is the usage of the node N
#       Sn is the size  of the node N
#
# Au = average utilisation = (E0..N Nu(n)) / N
#
# Using node utilisation takes into account that all NUMA nodes are not
# necessarily the same size.
#
# Memorybalance = geometric_mean(E0..N (abs(Nu - Au) / Au))
#
# Return value is between 0 and 1. 0 implies that nodes are perfectly
# balanced.
sub numa_memory_balance {
        my $elements = $#_ + 1;
        my $i;
	my @Nu;

        for ($i = 0; $i < $elements; $i += 2) {
		push @Nu, ($_[$i] / $_[$i+1]);
	}

	my $Au = calc_mean(@Nu);
	my $nodes = $#Nu + 1;

	my @averageDrift;
	for ($i = 0; $i < $nodes; $i++) {
		my $offset = abs($Nu[$i] - $Au);
		my $imbalance = $offset / $Au;
		
		push @averageDrift, $imbalance;
	}

	return calc_geomean(@averageDrift);
}

1;
