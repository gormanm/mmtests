# ExtractMlc.pm
package MMTests::ExtractMlc;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_ModuleName} = "ExtractMlc";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_Operations} = [
		"Reads-All",
		"RW-3:1",
		"RW-2:1",
		"RW-1:1" ];
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/peak_injection_bandwidth-*.log>) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			if ($line !~ /\s:\s/) {
				next;
			}

			my @elements = split(/\s+/, $line);
			$elements[1] =~ s/Reads-Writes/RW/;
			$elements[0] =~ s/ALL/All/;
			$self->addData("$elements[1]-$elements[0]", ++$iteration, $elements[3]);
		}
		close(INPUT);
	}
}
