# ExtractSimoop.pm
package MMTests::ExtractSimoop;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use MMTests::Stat;
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSimoop";
	$self->{_DataType}   = DataTypes::DATA_TIME_NSECONDS;
	$self->{_Opname}     = "Time";
	$self->{_ExactSubheading} = 1;
	$self->{_ExactPlottype}   = "simple";
	$self->{_PlotType}   = "simple";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my $reading = 0;
	my $timestamp;
	my (%fp50, %fp95, %fp99);
	open(INPUT, "$reportDir/$profile/simoop.log") || die "Failed to open simoop.log";
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		chomp($line);

		if ($line =~ /^Warmup complete/) {
			$reading = 1;
		}
		next if !$reading;


		if ($line =~ /Run time: ([0-9]*) seconds/) {
			$timestamp = $1;
			next;
		}

		my $op;
		my ($p50,  $p95,  $p99);
		if ($line =~ /([a-zA-Z]*) latency \(p50: ([0-9,]*)\) \(p95: ([0-9,]*)\) \(p99: ([0-9,]*)\)/) {
			$op = $1;
			$p50 = $2;
			$p95 = $3;
			$p99 = $4;

			$p50 =~ s/,//g;
			$p95 =~ s/,//g;
			$p99 =~ s/,//g;

			$fp50{$op} = $p50;
			$fp95{$op} = $p95;
			$fp99{$op} = $p99;

			push @{$self->{_ResultData}}, [ "p50-$op", $timestamp, $p50 ];
			push @{$self->{_ResultData}}, [ "p95-$op", $timestamp, $p95 ];
			push @{$self->{_ResultData}}, [ "p99-$op", $timestamp, $p99 ];
		}

	}
	close(INPUT);
	for my $op ("Read", "Write", "Allocation") {
		push @{$self->{_ResultData}}, [ "final-p50-$op", $timestamp, $fp50{$op} ];
		push @{$self->{_ResultData}}, [ "final-p95-$op", $timestamp, $fp95{$op} ];
		push @{$self->{_ResultData}}, [ "final-p99-$op", $timestamp, $fp99{$op} ];
	}

	$self->{_Operations} = [
		"p50-Read",
		"p95-Read",
		"p99-Read",
		"p50-Write",
		"p95-Write",
		"p99-Write",
		"p50-Allocation",
		"p95-Allocation",
		"p99-Allocation",
		"final-p50-Read",
		"final-p95-Read",
		"final-p99-Read",
		"final-p50-Write",
		"final-p95-Write",
		"final-p99-Write",
		"final-p50-Allocation",
		"final-p95-Allocation",
		"final-p99-Allocation"

	];
}

1;
