# ExtractScimarkc.pm
package MMTests::ExtractScimarkc;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractScimarkc";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_MINUTE;
	$self->{_PlotType}   = "histogram";
	$self->{_ClientSubheading} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my %opNames;
	my $iteration = 0;

	foreach my $file (<$reportDir/scimarkc.*>) {
		open(INPUT, $file) || die("Failed to open $file\n");
		$iteration++;
		while (<INPUT>) {
			my $line = $_;
			next if $line !~ /Mflops:/;

			my @elements = split(/\s+/, $line);
			$elements[0] =~ s/ /_/;

			$opNames{$elements[0]} = 1;
			$self->addData("$elements[0]", $iteration, $elements[2]);
		}
		close(INPUT);
	}

	my @ops;
	my @opNameSorted = sort keys %opNames;
	foreach my $opName (@opNameSorted) {
		push @ops, "$opName";
	}
	$self->{_Operations} = \@ops;
}

1;
