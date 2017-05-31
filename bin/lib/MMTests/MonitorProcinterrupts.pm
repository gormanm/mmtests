# MonitorProcinterrupts.pm
package MMTests::MonitorProcinterrupts;
use MMTests::SummariseMultiops;
use VMR::Report;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorProcinterrupts",
		_DataType      => DataTypes::DATA_OPS_PER_SECOND,
		_FieldLength   => 12,
		_ResultData    => [],
		_PlotType      => "simple",
		_PlotXaxis     => "Time"
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

        my $fieldLength = 24;
        $self->{_FieldLength} = $fieldLength;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%-${fieldLength}s", "%${fieldLength}.2f" ];
	$self->{_FieldHeaders} = [ "Source", "Mean" ];
        $self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $format;
	my $start_timestamp = 0;

	my ($subHeading, $subSummary) = split(/-/, $subHeading);

	my %sources;
	my %last_sources;
	my %fired;

	my $file = "$reportDir/proc-interrupts-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	while (!eof(INPUT)) {
		my $line = <INPUT>;
		$line =~ s/^\s+//;

		if ($line =~ /^time: ([0-9]+)/) {
			if ($start_timestamp == 0) {
				$start_timestamp = $1;
			} else {
				if ($timestamp - $start_timestamp > 0) {
					foreach my $source (sort keys %sources) {
						my $count = $sources{$source} - $last_sources{$source};
						if ($count > 10) {
							push @{$self->{_ResultData}}, [ $source, $timestamp - $start_timestamp, $sources{$source} - $last_sources{$source} ];
							$fired{$source} = 1;
						}
					}
				}
			}
			%last_sources = %sources;
			%sources = ();
			$timestamp = $1;

			# skip header
			$line = <INPUT>;
			next;
		}

		# Accumulate counts for this interrupt source
		my @elements = split (/\s+/, $line);
		my $source = "";
		my $nr = 0;
		my $reading_cpus = 1;
		for (my $i = 1; $i <= $#elements; $i++) {
			if ($elements[$i] =~ /\d+$/ && $reading_cpus) {
				$nr += $elements[$i];
			} else {
				$reading_cpus = 0;
				if ($source eq "") {
					$source = $elements[$i];
				} else {
					$source .= "-" . $elements[$i];
				}
			}
		}
		if ($source ne "") {
			$source =~ s/msix[0-9]+/msixN/;
			$source =~ s/MSI-[0-9]+/MSI-N/g;
			$source =~ s/TxRx-[0-9]+/TxRx-N/g;
			$sources{"$source;"} += $nr;
		}
	}

	my @operations = ( sort keys %fired );
	$self->{_Operations} = \@operations;
}

1;
