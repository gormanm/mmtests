# MonitorIotop.pm
package MMTests::MonitorIotop;
use MMTests::Monitor;
use VMR::Report;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorIoop",
		_DataType      => MMTests::Monitor::MONITOR_IOTOP,
		_RowOrientated => 1,
		_ResultData    => []
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

	if (!defined $_colMap{$subHeading}) {
		die("Unrecognised heading");
	}
	my $headingIndex = $_colMap{$subHeading};
	$self->{_HeadingIndex} = $headingIndex;

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 25;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "time", "process", $subHeading ];
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}s", "%${fieldLength}.2f" ];

	my $file = "$reportDir/iotop-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	my $reading;
	while (<INPUT>) {
		my $line = $_;
		$line =~ s/^\s+//;

		if ($line =~ /^time: ([0-9]+)/) {
			$timestamp = $1;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
			$reading = 0;
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
				# printf("%15d %20s %12.2f\n", $timestamp, $shortTask, $val);
				push @{$self->{_ResultData}},
					[ $timestamp - $start_timestamp, $shortTask, $val ];
			}
		}
	}
}

1;
