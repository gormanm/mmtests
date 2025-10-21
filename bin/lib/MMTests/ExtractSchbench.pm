# ExtractSchbench.pm
package MMTests::ExtractSchbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);

use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSchbench";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_USECONDS;
	$self->{_PlotXaxis}  = "Threads";
	$self->{_Opname} = "Lat";
	$self->{_FieldLength} = 12;
	$self->{_ExactSubheading} = 0;
	$self->{_ExactPlottype} = "simple";
	$self->{_DefaultPlot} = "1";
	if ($subHeading eq "RPS") {
		$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_SECOND;
		$self->{_PreferredVal} = "Higher";
	}
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @ratioops;
	my $reading = 0;
	my $metric = "";

	my @groups = $self->discover_scaling_parameters($reportDir, "schbench-", ".log");
	foreach my $group (@groups) {
		my $input = $self->SUPER::open_log("$reportDir/schbench-$group.log");
		my $nr_intervals = 0;
		while (!eof($input)) {
			my $line = <$input>;
			if ($line =~ /^Wakeup Latencies percentiles.*\(([0-9]+) total samples/) {
				$nr_intervals++;
			}
		}
		seek $input, 0, 0;

		my $interval = 0;
		while (!eof($input)) {
			my $line = <$input>;
			if ($line =~ /^([a-zA-Z]+) Latencies percentiles.*\(([0-9]+) total samples/) {
				$reading = 0;
				$metric = $1;
				$interval++  if $metric eq "Wakeup";
				$reading = 1 if ($interval != $nr_intervals && $2 > 0);
			} elsif ($line =~ /^RPS percentiles/) {
				$metric = "RPS";
			} elsif ($reading == 1) {
				if ($line =~ /[ \t\*]+([0-9]+\.[0-9]+)th: ([0-9]+).*\(([0-9]+) samples/) {
					my $quartile = $1;
					my $lat = $2;
					my $samples = $3;
					$quartile =~ s/\.0+$//;
					if (($metric ne "RPS" && $quartile == 99) ||
					    ($metric eq "RPS" && $quartile == 50)) {
						push @ratioops, "$metric-${quartile}th-$group";
					}

					if ($samples > 0) {
						$self->addData("$metric-${quartile}th-$group", $interval, $lat);
					}
				}
				if ($line =~ /.*max=([0-9]+)/) {
					my $lat = $1;
					$self->addData("$metric-max-$group", $interval, $lat);
				}
			} else {
				$reading = 0;
			}
		}
		close $input;
	}

	$self->{_RatioOperations} = \@ratioops;
}
