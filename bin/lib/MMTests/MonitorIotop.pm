# MonitorIotop.pm
package MMTests::MonitorIotop;
use MMTests::Monitor;
use MMTests::Stat;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorIoop",
		_DataType      => MMTests::Monitor::MONITOR_IOTOP,
		_ResultData    => [],
		_MultiopMonitor => 1
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

sub printDataType() {
	my ($self) = @_;
	my $headingIndex = $self->{_HeadingIndex};

	if ($headingIndex == 3) {
		print "Read,Time,Read\n";
	} elsif ($headingIndex == 5) {
		print "Write,Time,Write\n";
	} else {
		print "Unknown\n";
	}
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $format;
	my $start_timestamp = 0;

	my ($subOp, $subCalc) = split(/-/, $subHeading);
	if ($subCalc ne "") {
		if ($subCalc eq "mean") {
			$subCalc = "calc_harmmean";
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
	$self->{_HeadingIndex} = $headingIndex;

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 25;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "Process", "Time", $subHeading ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}d", "%${fieldLength}.2f" ];

	my $file = "$reportDir/iotop-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	my $reading;
	my @vals;
	while (<INPUT>) {
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
						&$subCalc(@vals));
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
}

1;
