#!/usr/bin/perl
# reports-from-json.pl - Returns a list of distinct benchmark names in a JSON
# file containing test runs results.
# These names are extracted from the _ModuleName field of each test run.
#
# Author:    Mirco Romagnoli, 2021

use Getopt::Long;
use JSON;
use Pod::Usage;
use Data::Dumper;
use strict;

# Option variable
my ($opt_help, $opt_manual);
my ($opt_from_json);
GetOptions(
	'help|h'	=> \$opt_help,
	'manual'	=> \$opt_manual,
	'<>'		=> \&processJSON
);
pod2usage(-exitstatus => 0, -verbose => 0) if $opt_help;
pod2usage(-exitstatus => 0, -verbose => 2) if $opt_manual;

sub uniq() {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub processJSON() {
	my ($filename) = @_;

	my $json_src = "";
	open(FH, '<', $filename) or die $!;
	foreach my $line (<FH>) {
		chomp($line);
		$json_src = $json_src . $line;
	}
	my @extracted_names;
	my @modules = @{from_json($json_src)};
	for my $module (@modules) {
		my $module_name = $module->{"_ModuleName"};
		$module_name =~ s/Extract//;
		$module_name = lc($module_name);
		push(@extracted_names, $module_name);
	}
	my %seen = ();
	my @unique = grep { ! $seen{$_} ++ } @extracted_names;
	print "@unique\n";
	exit(0);
}

exit(0);

# Below this line is help and manual page information
__END__

=head1 NAME

reports-from-json.pl - Returns a list of distinct benchmark names in a JSON file containing test runs results.

=head1 SYNOPSIS

reports-from-json.pl json_file

 Options:
 --manual	Print manual page
 --help		Print help message

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=back

=head1 DESCRIPTION

The correct JSON format is the one produced by extract-mmtests.pl with the "--print-json" option.
The "_ModuleName" value will be read for each JSON object contained in the provided JSON array.


=head1 AUTHOR

Written by Mirco Romagnoli <romagnoli.mirco@gmail.com>

=head1 REPORTING BUGS

Report bugs to the author.

=cut
