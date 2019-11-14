# MonitorPerftimestat.pm
package MMTests::MonitorPerftimestat;
use MMTests::SummariseMonitor;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMonitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorPerftimestat",
	};
	bless $self, $class;
	return $self;
}

my %headingnames => {
	"cpu-migrations"	=> "CPU Migrations",
	"context-switches"	=> "Context Switches",
	"task-clock"		=> "Task Clock",
	"page-faults"		=> "Page Faults",
	"cycles"		=> "Cycles",
	"instructions"		=> "Instructions",
	"branches"		=> "Branches",
	"branch-misses"		=> "Branch Misses",
};

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_FieldLength}   = 18;
	$self->{_ExactSubheading} = 1;
	$self->{_DataType} = DataTypes::DATA_ACTIONS;
	$self->{_PlotXaxis} = "Time";
	$self->{_PlotYaxes} = "cpu-migrations";
	$self->{_PlotType}  = "simple";
	$self->SUPER::initialise($subHeading);
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $timestamp;
	my $start_timestamp = 0;

	if ($subHeading ne "") {
		$self->{_PlotYaxes} = $headingnames{$subHeading};
	}

	# Read all counters
	my $timestamp;
	my $start_timestamp = 0;
	my $reading = 0;

	my $input = $self->SUPER::open_log("$reportDir/perf-time-stat-$testBenchmark");
	while (!eof($input)) {
		my $line = <$input>;

		if ($line =~ /^time: ([0-9]+)/) {
			$reading = 0;
			$timestamp = $1;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
		}

		if ($line =~ /Performance counter stats for.*/) {
			$reading = 1;
			next;
		}
		next if $reading != 1;
		next if $line =~ /seconds time elapsed/;
		if ($line =~ /\s+([0-9,\.]+)\s+([A-Za-z-]+).*/) {
			my ($counter, $heading) = ($1, $2);

			next if ($subHeading ne "" && $heading ne $subHeading);

			$counter =~ s/,//g;
			$self->addData($heading, $timestamp - $start_timestamp, $counter );
		}
	}

	close($input);
}

1;
