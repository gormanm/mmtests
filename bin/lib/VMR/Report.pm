#
# Report.pm
#
# This very simple module is simply for keeping report generation
# in the same place. The code is basically a glorified collection
# of print statements

package VMR::Report;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;
use VMR::File;
my $verbose;

@ISA    = qw(Exporter);
@EXPORT = qw(&setVerbose &printVerbose &reportHeader &reportPrint &reportZone &reportTest &reportGraph &reportEnvironment &reportFooter &reportOpen &reportClose);

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
#
# reportHeader - Print the HTML header and title
# @title: Title of report
sub reportHeader {
  my ($title) = @_;
  my $dashes;

  print HTML <<"EOF";
<html>
  <head>
    <title>$title</title>
  </head>

  <body>
    <pre>$title
EOF
  # Print dashes to underline title
  if (length($title) != 0) {
    for ($dashes=0; $dashes < length($title); $dashes++) {
      print HTML "-";
    }
  }
  print HTML "\n\n";


}

##
# reportPrint - Print a string verbatim to the report
# @string:	String to print
sub reportPrint {
  my ($string) = @_;

  print HTML $string;
}

##
#
# reportZone - Print out the current node/zone information
# @append: String to append to title (e.g. Before Test)

sub reportZone {
  my ($append) = @_;
  my $dashes;

  # Print header
  print HTML "Node/Zone Information $append\n";
  print HTML "---------------------";

  # Print dashes to underline appended text to title
  if (length($append) != 0) {
    for ($dashes=0; $dashes <= length($append); $dashes++) {
      print HTML "-";
    }
  }
  print HTML "\n";

  # Print zone information
  print HTML readproc("sense_zones");
}

##
#
# reportTest - Print out the test results
# @result:Results
sub reportTest {
  my ($result) = @_;

  print HTML "$result\n";
}

##
# reportGraph - Show a graph
# @caption:    Caption to give the graph
# @path:       Path to output image
# @psfile:     Postscript source of the image
# @pngfile:    PNG file of the image
sub reportGraph {
  my ($caption, $path, $psfile, $pngfile) = @_;
  if ( -e "$path$psfile" ) {
  print HTML <<"EOF";
    <center>
      <b>$caption</b>
      <a href="$psfile"><img src="$pngfile"></a>
    </center>
    <br><br>
EOF
  } else {
    print "Graph '$path$psfile' does not exist\n";
  }
}

##
#
# reportEnvironment - Print out information on the test environment
# @vmstat: vmstat output

sub reportEnvironment {
  my ($vmstat) = @_;

  # Print Zone information
  reportZone("After Test");

  # Print CPU info
  print HTML "CPU Information (/proc/cpuinfo)\n";
  print HTML "-------------------------------\n";
  print HTML readproc("/proc/cpuinfo");

  # Print Memory info
  print HTML "\nMemory Information (/proc/meminfo)\n";
  print HTML "-----------------------------------\n";
  print HTML readproc("/proc/meminfo");

  # Print vmstat information
  print HTML "\nvmstat -n 1 output\n";
  print HTML "------------------\n";
  print HTML $vmstat;
}

##
#
#  reportFooter - Print the footer of the report page
sub reportFooter {

  print HTML <<"EOF";
    <h6> Benchmark produced by VM Regress (http://www.csn.ul.ie/~mel/projects/vmregress)</h6>
  </body>
</html>
EOF
}

##
#
# reportOpen - Open a new report
# @filename: Filename of report to open
sub reportOpen {
  my ($filename) = @_;

  open (HTML, ">$filename") or die("Could not open $filename");
}

##
#
# reportClose - Close the report
sub reportClose {
  close HTML;
}

1;
