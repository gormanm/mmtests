# MonitorIotop.pm
package MMTests::MonitorIotop;
use MMTests::SummariseMonitor;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMonitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorIotop",
		_FieldLength   => 25,
		_PlotType      => "operation-candlesticks",
	};
	bless $self, $class;
	return $self;
}

my %_colMap = (
	"PID"		=> 0,
	"User"		=> 2,
	"Read"		=> 3,
	"Write"		=> 5,
	"Swapin"	=> 7,
	"IO"		=> 9,
	"Proc"		=> 11,
);

my %labelMap = (
	"Read"	=> DataTypes::LABEL_KBYTES_PER_SECOND,
	"Write"	=> DataTypes::LABEL_KBYTES_PER_SECOND,
	"Swapin" => "Percent",
	"IO"	=> "Percent",
);

sub getPlotYaxis() {
	my ($self, $op) = @_;
	my @elements = split(/-/, $op);

	return $labelMap{$elements[0]};
}

# For iotop monitor subHeading defines processing during extraction. Not
# selection of operations.
sub filterSubheading() {
	my ($self, $subHeading, $opref) = @_;

	return @{$opref};
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $format;
	my $start_timestamp = 0;

	my ($subOp, $subCalc) = split(/-/, $subHeading);
	if ($subCalc ne "") {
		if ($subCalc eq "mean") {
			$subCalc = "calc_hmean";
		} elsif ($subCalc eq "stddev") {
			$subCalc = "calc_stddev";
		} else {
			die("Unrecognised subcalc $subCalc");
		}
	}
	if (!defined $_colMap{$subOp}) {
		die("Unrecognised heading '$subOp'");
	}
	my $headingIndex = $_colMap{$subOp};

	my $input = $self->SUPER::open_log("$reportDir/iotop-$testBenchmark");

	my $reading;
	my @vals;
	while (<$input>) {
		my $line = $_;
		$line =~ s/^\s+//;

		if ($line =~ /^time: ([0-9]+)/) {
			if ($start_timestamp == 0) {
				$timestamp = $1;
				$start_timestamp = $timestamp;
			} else {
				if ($subCalc ne "" && $#vals >= 0) {
					no strict "refs";
					$self->addData("threads",
						$timestamp - $start_timestamp,
						&$subCalc(\@vals));
				}
				$timestamp = $1;
			}
			$reading = 0;
			$#vals = -1;
			next;
		}
		if ($reading == 0 && $line =~ /^TID/) {
			$reading = 1;
			next;
		}

		if ($reading) {
			my @elements = split(/\s+/, $line);

			my $fullTask = $elements[$_colMap{"Proc"}] . "-" . $elements[$_colMap{"PID"}];
			my $shortTask = $elements[$_colMap{"Proc"}];
			my $val = $elements[$headingIndex];

			if ($val > 5) {
				if ($subCalc eq "") {
					$self->addData($shortTask,
						$timestamp - $start_timestamp,
						$val);
				}
				push @vals, $val;
			}
		}
	}

	close($input);
}

1;
