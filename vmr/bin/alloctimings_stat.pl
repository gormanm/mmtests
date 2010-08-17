#!/usr/bin/perl
#
# alloctimings_stat
#
# The highalloc kernel module (used by bench-stresshighalloc) generates
# a timing report in /proc/vmregress/test_highalloc_timings that shows
# the number of clock cycles taken for each allocation. This program
# generates a report showing the ranges of times spent allocating the
# pages

use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use Pod::Usage;
use VMR::File;
use VMR::Report;
use File::Basename;
use strict;
no strict 'refs';

# Option variables
my $man  =0;
my $help =0;
my $opt_delay = -1;
my $opt_verbose = 0;

# Proc variables
my $proc;		# Proc entry read into memory

# Output related

# Time related
my $starttime;
my $duration;

# Get options
GetOptions(
	'help|h'   => \$help, 
	'man'      => \$man,
	'verbose'  => \$opt_verbose,
	'delay|n'  => \$opt_delay);

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
$opt_verbose && setVerbose();

$proc = readproc("/proc/vmregress/test_highalloc_timings");

# Process proc entry
my @alloc_timings_range;
my @failed_timings_range;
my $timing;
my @unsorted_alltimings;
foreach $timing (split /\s+/, $proc) {
  $unsorted_alltimings[$#unsorted_alltimings+1] = $timing;
}
my @alltimings = sort { $a <=> $b } @unsorted_alltimings;

# Work out averages, max, min and sort into ranges
foreach $timing (@alltimings) {
  my $num_ranges = $#alloc_timings_range;

  # Find a range for this
  #  > 0 implies successful allocation
  #  < 0 implies failed allocation
  #  0 makes no sense
  if ($timing > 0) {
    my $found=0;
    for (my $i=0; $i <= $#alloc_timings_range && !$found; $i++) {
      my $range = $alloc_timings_range[$i];
      if (abs ($$range{"average"} - $timing) < $$range{"average"} / 2) {
      	my $oldtotal = $$range{"total"};
        $$range{"total"} += $timing;
	if ($oldtotal > $$range{"total"}) {
	  print "ERROR: Overflowed " . $$range{"average"} . "\n";
	}
        $$range{"allocs"}++;
        $$range{"average"} = $$range{"total"} / $$range{"allocs"};
        if ($timing < $$range{"min"}) { $$range{"min"} = $timing; }
        if ($timing > $$range{"max"}) { $$range{"max"} = $timing; }
        printVerbose("Fnd alloc: $timing -> " . $$range{"average"} . "\n");
        $found=1;
      }
    }

    # Range not found, this is a new one
    if (!$found) {
      my %range ;
      $range{"total"}  = $timing;
      $range{"allocs"} = 1;
      $range{"average"} = $timing;
      $range{"min"} = $timing;
      $range{"max"} = $timing;
      $alloc_timings_range[$#alloc_timings_range+1] = \%range;
      printVerbose("New alloc: $timing\n");
    }
  } else {
    my $found=0;
    $timing = abs $timing;
    for (my $i=0; $i <= $#failed_timings_range && !$found; $i++) {
      my $range = $failed_timings_range[$i];
      if (abs ($$range{"average"} - $timing) < $$range{"average"} / 2) {
        $$range{"total"} += $timing;
        $$range{"failed"}++;
        $$range{"average"} = $$range{"total"} / $$range{"failed"};
        if ($timing < $$range{"min"}) { $$range{"min"} = $timing; }
        if ($timing > $$range{"max"}) { $$range{"max"} = $timing; }
        printVerbose("Fnd  fail: $timing -> " . $$range{"average"} . "\n");
        $found=1;
      }
    }

    # Range not found, this is a new one
    if (!$found) {
      my %range ;
      $range{"total"}  = $timing;
      $range{"failed"} = 1;
      $range{"average"} = $timing;
      $range{"min"} = $timing;
      $range{"max"} = $timing;
      $failed_timings_range[$#failed_timings_range+1] = \%range;
      printVerbose("New  fail: $timing\n");
    }
  }
}

# Work out the initial part of the standard deviation here
# Note that the final / 2 and sqrt parts of the calculation
# do not happen until later
foreach $timing (@alltimings) {

  if ($timing > 0) {
    my $found = 0;
    for (my $i=0; $i <= $#alloc_timings_range && !$found; $i++) {
      my $range = $alloc_timings_range[$i];
      if (abs ($$range{"average"} - $timing) < $$range{"average"} / 2) {
        $$range{"stddev"} += ($timing - $$range{"average"})**2;
        $found=1;
      }
    }

    # Range not found, this is a new one
    if (!$found) {
      print "WARNING: Could not find range bin for $timing\n";
    }
  } else {
    my $found=0;
    $timing = abs $timing;
    for (my $i=0; $i <= $#failed_timings_range && !$found; $i++) {
      my $range = $failed_timings_range[$i];
      if (abs ($$range{"average"} - $timing) < $$range{"average"} / 2) {
        $$range{"stddev"} += ($timing - $$range{"average"})**2;
        $found=1;
      }
    }

    # Range not found, this is a new one
    if (!$found) {
      print "WARNING: Could not find range bin for $timing\n";
    }
  }
}

# Sort result
@alloc_timings_range  = sort { $$a{"average"} <=> $$b{"average"} } @alloc_timings_range;
@failed_timings_range = sort { $$a{"average"} <=> $$b{"average"} } @failed_timings_range;

# Print allocated report
printf "%12s %12s %12s %12s %5s\n", "Average", "Max", "Min", "StdDev", "Allocs";
printf "%12s %12s %12s %12s %5s\n", "-------", "---", "---", "------", "------";

for (my $i=0; $i <= $#alloc_timings_range; $i++) {
  my $range = $alloc_timings_range[$i];
  $$range{"stddev"} = sqrt ($$range{"stddev"} / $$range{"allocs"});
  printf "%12.2f %12d %12d %12.2f %6d\n", 
    $$range{"average"},
    $$range{"max"},
    $$range{"min"},
    $$range{"stddev"},
    $$range{"allocs"};
}
  
# Print failed report
printf "\n%12s %12s %12s %12s %5s\n", "Average", "Max", "Min", "StdDev", "Failed";
printf "%12s %12s %12s %12s %5s\n", "-------", "---", "---", "------", "------";

for (my $i=0; $i <= $#failed_timings_range; $i++) {
  my $range = $failed_timings_range[$i];
  $$range{"stddev"} = sqrt ($$range{"stddev"} / $$range{"failed"});
  printf "%12.2f %12d %12d %12.2f %6d\n", 
    $$range{"average"},
    $$range{"max"},
    $$range{"min"},
    $$range{"stddev"},
    $$range{"failed"};
}
printf "\nNote, Average Max and Min are measured in clock cycles\n";
 
# Below this line is help and manual page information
__END__

=head1 NAME

extfrag_stat - Measure the extend of external fragmentation in the kernel

=head1 SYNOPSIS

extfrag_stat.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  n, --delay      Print a report every n seconds

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<-n, --delay>

By default, a single report is generated and the program exits. This option
will generate a report every requested number of seconds.

=back

=head1 DESCRIPTION

No detailed description available. Consult the full documentation in the
docs/ directory

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
