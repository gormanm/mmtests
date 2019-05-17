# ExtractXfstests.pm
package MMTests::ExtractXfstests;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractXfstests";
	$self->{_DataType}   = DataTypes::DATA_BAD_ACTIONS;
	$self->{_SingleType} = 1;
	$self->{_Opname} = "Test";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $file = "$reportDir/xfstests-default.log";

	my %status;
	my @all_tests;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		next if $line !~ /^([a-z]+\/[0-9a-z]+)\s(.*)/;

		my $xfstest = $1;
		my $results = $2;
		$results =~ s/([\s\.0-9a-z]*\[)?/\[/;

		my @elements = split /[\[\]]/, $results;
		next if $elements[5] =~ /^not run$/;

		$status{$xfstest} = 0;
		if ($elements[3] =~ /failed.*([0-9])+/) {
			$status{$xfstest} = $1;
		}
		push @all_tests, $xfstest;
	}

	foreach my $xfstest (@all_tests) {
		$self->addData($xfstest, 0, $status{$xfstest})
	}

	close(INPUT);
}

1;
