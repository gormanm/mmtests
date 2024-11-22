# MonitorBdi
package MMTests::MonitorBdi;
use MMTests::SummariseMonitor;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMonitor);

use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "MonitorBdi";
	$self->{_PlotType} = "simple";
	$self->{_DefaultPlot} = "BdiWriteBandwidth";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

my %labelMap = (
	"BdiWriteback"		=> DataTypes::LABEL_KBYTES,
	"BdiReclaimable"	=> DataTypes::LABEL_KBYTES,
	"BdiDirtyThresh"	=> DataTypes::LABEL_KBYTES,
	"DirtyThresh"		=> DataTypes::LABEL_KBYTES,
	"BackgroundThresh"	=> DataTypes::LABEL_KBYTES,
	"BdiDirtied"		=> DataTypes::LABEL_KBYTES,
	"BdiWritten"		=> DataTypes::LABEL_KBYTES,
	"BdiWriteBandwidth"	=> DataTypes::LABEL_KBYTES_PER_SECOND,
);

sub getPlotYaxis() {
	my ($self, $op) = @_;
	my @elements = split(/-/, $op);

	return $labelMap{$elements[1]};
}


my %devices;

sub extractReport($$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $start_timestamp = 0;
	my $input;

	$input = $self->SUPER::open_log("$reportDir/bdi-$testBenchmark");

	my $fieldLength = 12;
        $self->{_FieldLength} = $fieldLength;
        $self->{_FieldFormat} = [ "%${fieldLength}.4f", "%${fieldLength}.2f" ];

	my %last_value;
	my $timestamp;

	while (<$input>) {
		my @elements = split (/\s+/, $_);

		if ($elements[0] eq "time:") {
			$timestamp = $elements[1];
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
				$timestamp = 0;
			} else {
				$timestamp -= $start_timestamp;
			}
			next;
		}

		@elements[0] =~ s/://;
		my $report = 0;
		foreach my $op (keys %typeMap) {
			if ($elements[0] eq $op) {
				$report = 1;
				last;
			}
		}
		next if !$report;
		next if $subHeading ne "" && $subHeading ne $elements[0];

		if ($elements[0] ne "BdiDirtied" ||
		    $elements[0] ne "BdiWritten") {
			if ($last_value{$elements[0]} == 0) {
				$last_value{$elements[0]} = $elements[1];
				$elements[1] = 0;
			} else {
				my $last = $last_value{$elements[0]};
				$last_value{$elements[0]} = $elements[1];
				$elements[1] -= $last;
			}
		}
		$self->addData($elements[0], $timestamp, $elements[1]);
	}

	close($input);
}

1;
