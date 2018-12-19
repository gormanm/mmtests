# ExtractSpecjvm.pm
package MMTests::ExtractSpecjvm;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSpecjvm";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_MINUTE;
	$self->{_PlotType}   = "histogram";
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $section = 0;
	my $pagesize = "base";

	if (! -e "$reportDir/$profile/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/$profile/$pagesize") {
		$pagesize = "default";
	}

	my $file = "$reportDir/$profile/$pagesize/SPECjvm2008.001/SPECjvm2008.001.txt";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /======================/) {
			$section++;
			next;
		}

		if ($section == 4 && $line =~ /iteration [0-9]+/) {
			my ($bench, $dA, $dB, $dC, $dD, $dE, $ops) = split(/\s+/, $line);
			if ($bench !~ /startup/) {
				push @{$self->{_ResultData}}, [ $bench, 0, $ops ];
			}
		}
	}
	close INPUT;
}

1;
