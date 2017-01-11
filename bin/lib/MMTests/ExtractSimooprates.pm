# ExtractSimooprates.pm
package MMTests::ExtractSimooprates;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use VMR::Stat;
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSimooprates";
	$self->{_DataType}   = MMTests::Extract::DATA_OPS_PER_SECOND;
	$self->{_Opname}     = "Time";
	$self->{_ExactSubheading} = 1;
	$self->{_ExactPlottype}   = "simple";
	$self->{_PlotType}   = "simple";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	$reportDir =~ s/simooprates/simoop/;

	my $reading = 0;
	my $timestamp;
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

		if ($line =~ /([a-zA-Z ]*) rate = ([0-9.]*)\/sec/) {
			my $op = $1;
			my $rate = $2;
			$op =~ s/alloc stall/stall/;
			push @{$self->{_ResultData}}, [ "$op", $timestamp, $rate ];
		}

	}
	close(INPUT);
	$self->{_Operations} = [ "work", "stall" ];
}

1;
