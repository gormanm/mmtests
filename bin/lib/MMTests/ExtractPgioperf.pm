# ExtractPgioperf.pm
package MMTests::ExtractPgioperf;
use MMTests::SummariseVariabletime;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;

	$self->{_ModuleName} = "ExtractPgioperf";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_MSECONDS;
	$self->{_ExactSubheading} = 1;
	$self->{_PlotType} = "simple-filter";
	$self->{_DefaultPlot} = "1";

	$self->SUPER::initialise($reportDir, $testName);
}

sub printDataType() {
	print "Time,Sample Index,Latency,points";
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $recent = 0;

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
			push @{$self->{_ResultData}}, [ $op, ++$samples, $max ];

		}
	}
	$self->{_Operations} = [ "commit", "read", "wal" ];
	close INPUT;
}

1;
