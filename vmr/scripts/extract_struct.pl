#!/usr/bin/perl
# This perl script attemps to extract a struct from a given C file and print it out

use strict;

#
# Make sure we're looking at a real struct definition
#
sub is_notstruct 
{
	my $cfile = $_[0];
	my $bdex = $_[1];
	my $structname = $_[2];

	#
	# See if we're in a comment block.
	#
	my $cpos = 0;
	my $epos = 0;
	my $letter;
	
	while(1) {
		$cpos = index($cfile, "/*", $epos);

		if ($cpos == -1) {
			last;
		}

		$epos = index($cfile, "*/", $cpos);
		if ($epos == -1) {
			return 1;
		}
		if ($bdex > $cpos && $bdex < $epos) {
			return 1;
		}

	};

	#
	# next non-whitespace needs to be '{'
	#
	$cpos = $bdex + length($structname);
	do {
		$letter = substr($cfile, $cpos++, 1);
		if ($letter eq '{') {
			return 0;
		}
		if ($letter ne ' ' && $letter ne '\n' && $letter ne '\t') {

			return 1;
		}
	} while (1);

}

my $cfilename;		# C filename
my $structname;		# Name of the struct to extract
my $ifdef;		# A #ifdef to wrap the struct around
my $cfile;		# The actual c file
my $cfilelength;	# Length of the c file
my $bidx;		# Index where struct begins
my $ridx;		# Index into cfile
my $bcount;		# Braces {} count
my $letter;		# Single letter in the cfile
my $struct;		# Output struct
my $notstruct;
my $eidx;

sub usage() {
	print("extract_struct \"[c file]\" \"struct name\"\n");
	print("(c) Mel Gorman 2002\n\n");
	exit();
}

# Get command line arguements
if ($ARGV[0] eq "" || $ARGV[1] eq "") { usage(); }
$cfilename  = $ARGV[0];
$structname = $ARGV[1];
$ifdef = $ARGV[2];

# Open C file and read it
open(FD, $cfilename) || exit();
while (!eof(FD)) {
	$cfile .= <FD>;
}
close(FD);
$cfilelength = length($cfile);

# Search forward for struct pattern
$notstruct = 0;
$eidx = 0;
do {
	$bidx = index($cfile, $structname, $eidx);
	if ($bidx == -1) {
		print("/* extract_struct.pl: Struct $structname not found. */\n");
		exit();
	}
	$notstruct = is_notstruct($cfile, $bidx, $structname);
	$eidx = $bidx + 1;
} while ($notstruct);

# Read forward to {
$ridx = $bidx;
do {
	$letter = substr($cfile, $ridx++, 1);
} while ($letter ne '{');

# Read structure
$bcount=1;
do {
	$letter = substr($cfile, $ridx++, 1);
	if ($letter eq '{') { $bcount++; }
	if ($letter eq '}') { $bcount--; }

	if ($ridx == $cfilelength) {
		print "End of file reached but not end of struct...\n";
		exit();
	}
} while ($bcount != 0);

# Read forward to ;
do {
	$letter = substr($cfile, $ridx++, 1);
} while ($letter ne ';');

# Extract structure
$struct = substr($cfile, $bidx, $ridx-$bidx);

# Output struct
if ($ifdef ne "") { print "#ifdef $ifdef\n"; }
print "/* From: $cfilename */\n";

# Check if this is typedef'd
if ( $struct =~ /}.*[a-zA-Z]+.*;$/ ) { print "typedef "; }
print "$struct\n";
if ($ifdef ne "") { print "#endif\n"; }
print "\n";
