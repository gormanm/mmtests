# Report.pm
#
# Glorified print statements
#
package VMR::Report;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
use VMR::File;
my $verbose;

@ISA    = qw(Exporter);
@EXPORT = qw(&setVerbose &printVerbose &printWarning);

##
# setVerbose - Set the verbose flag
sub setVerbose {
  $verbose = 1;
}

##
# printVerbose - Print debugging messages if verbose is set
# @String to print
sub printVerbose {
  $verbose && print @_;
}

##
# printWarning - Print a warning message is verbosity allows
# @String to print
sub printWarning {
  print STDERR "WARNING: @_\n";
}

1;
