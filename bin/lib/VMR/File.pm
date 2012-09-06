#
# File.pm
#
# This concerns itself with files such as creating temp filenames and
# read/writing proc entries. 

package VMR::File;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&mktempname &readproc &writeproc);

##
# mktempname - Make a temporary filename
# @name: Name of the program creating the tempname (optional)
#
# This function will return the name of a file that is unique. It is not bullet
# proof and doesn't guarentee two callers will create the same temp name at the
# same time but is sufficient for current purposes

sub mktempname {
	my $name = shift;
	my $ret;
	my $index=0;

	if ($name eq "") { $name = "vmregress"; }

	$ret = "/tmp/$name." . getppid();

	while (-e $ret && $index < 100) {
        	$ret = "/tmp/$name." . getppid() . ".$index";
        	$index++;
	}

	if ( -e $ret ) {
		die("Tried 100 temp filenames and failed.... dying");
	}

	return $ret;
}

##
#  readproc - Read a proc entry
#  @procentry: Name of the proc entry to read
#
#  The function will return the entire contents of a proc entry. If a full
#  path is not provided, the entry is presumed to be in /proc/vmregress

sub readproc {
	my $procentry = shift;
	my $proc="";

	if (! -e $procentry && $procentry !~ /^\//) {
		$procentry = "/proc/vmregress/$procentry";
	}

	open(PROC, $procentry) or die("Failed to open $procentry for reading");
	while (!eof(PROC) ) {
		$proc .= <PROC>;
	}
	
	close PROC;

	return $proc;
}

##
#  writeproc - Write to a proc entry
#  @procentry; Name of the proc entry to write
#  @write: Information to write to it
#
#  The contents of $write will be written to the specified procentry. If a
#  full path is not provided, the entry is presumed to be in /proc/vmregress
sub writeproc {
	my ($procentry, $write) = @_;
	$procentry = "/proc/vmregress/$procentry";

	open(PROC, ">$procentry") or die ("Failed to open $procentry for writing");
	print PROC $write;
	close PROC;
}
