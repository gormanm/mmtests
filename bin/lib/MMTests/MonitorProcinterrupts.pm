# MonitorProcinterrupts.pm
package MMTests::MonitorProcinterrupts;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorProcinterrupts",
		_PlotYaxis     => DataTypes::LABEL_OPS_PER_SECOND,
		_PreferredVal  => "Higher",
		_FieldLength   => 24,
		_PlotType      => "simple",
		_PlotXaxis     => "Time"
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $format;
	my $start_timestamp = 0;

	my ($subHeading, $subSummary) = split(/-/, $subHeading);

	my %sources;
	my %last_sources;
	my %fired;

	my $input = $self->SUPER::open_log("$reportDir/proc-interrupts-$testBenchmark");
	while (!eof($input)) {
		my $line = <$input>;
		$line =~ s/.* -- //;
		$line =~ s/^\s+//;

		if ($line =~ /^time: ([0-9]+)/) {
			if ($start_timestamp == 0) {
				$start_timestamp = $1;
			} else {
				if ($timestamp - $start_timestamp > 0) {
					foreach my $source (sort keys %sources) {
						my $count = $sources{$source} - $last_sources{$source};
						if ($count > 10) {
							$self->addData($source, $timestamp - $start_timestamp, $sources{$source} - $last_sources{$source} );
							$fired{$source} = 1;
						}
					}
				}
			}
			%last_sources = %sources;
			%sources = ();
			$timestamp = $1;

			# skip header
			$line = <$input>;
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
			$sources{"$source"} += $nr;
		}
	}
	close($input);

	my @operations = ( sort keys %fired );
	$self->{_Operations} = \@operations;
}

1;
