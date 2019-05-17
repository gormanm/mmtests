# ExtractPgioperfbench.pm
package MMTests::ExtractPgioperfbench;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $fieldLength = 12;

	$self->{_ModuleName} = "ExtractPgioperfbench";
	$self->{_DataType}   = DataTypes::DATA_TIME_MSECONDS;
	$self->{_ExactSubheading} = 1;
	$self->{_PlotType} = "simple-filter-points";
	$self->{_PlotXaxis} = "Sample Index";
	$self->{_DefaultPlot} = "1";

	$self->SUPER::initialise($reportDir, $testName);
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldFormat} = [ "%$fieldLength.4f" , "%${fieldLength}.2f" ];
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $recent = 0;
	my $start_time = 0;

	open(INPUT, "$reportDir/$profile/pgioperf.log") || die("Failed to open $reportDir/$profile/pgioperf.log");
	my $samples = 0;
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		if ($line =~ /^([a-z]+)\[[0-9]+\]: avg: ([0-9.]+) msec; max: ([0-9.]+) msec/i) {
			my $op = $1;
			my $avg = $2;
			my $max = $3;
			if ($op ne "read" && $op ne "commit" && $op ne "wal") {
				next;
			}
			$samples++;
			my $time = $samples;
			if ($line =~ /time:/) {
				my @elements = split(/\s+/, $line);
				$time = @elements[-1];
				if ($start_time == 0) {
					$start_time = $time;
				}
			}
			$self->addData($op, $time - $start_time, $max );

		}
	}
	$self->{_Operations} = [ "commit", "read", "wal" ];
	close INPUT;
}

1;
