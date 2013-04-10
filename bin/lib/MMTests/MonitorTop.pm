# MonitorTop.pm
package MMTests::MonitorTop;
use MMTests::Monitor;
use VMR::Report;
our @ISA = qw(MMTests::Monitor); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorTop",
		_DataType      => MMTests::Monitor::MONITOR_TOP,
		_RowOrientated => 1,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

my %_colMap = (
	"PID"	=> 0,
	"USER"	=> 1,
	"PR"	=> 2,
	"NI"	=> 3,
	"VIRT"	=> 4,
	"RES"	=> 5,
	"SHR"	=> 6,
	"S"	=> 7,
	"CPU"	=> 8,
	"MEM"	=> 9,
	"TIME"	=> 10,
);

sub printDataType() {
	my ($self) = @_;
	my $headingIndex = $self->{_HeadingIndex};

	if ($headingIndex == 8) {
		print "CPUUsage,Time,CPU Usage\n";
	} elsif ($headingIndex == 10) {
		print "Time,Time,Accumulated CPU Time\n";
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

	if ($subHeading eq "") {
		$subHeading = "kswapd~CPU";
	}

	my ($proc, $heading) = split(/~/, $subHeading);
	if (!defined $_colMap{$heading}) {
		die("Unrecognised heading");
	}
	my $headingIndex = $_colMap{$heading};
	$self->{_HeadingIndex} = $headingIndex;

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "time", $subHeading ];
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}f" ];

	my $file = "$reportDir/top-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	my $matched;
	my $reading;
	my $val = -1;
	while (<INPUT>) {
		if ($_ =~ /^time: ([0-9]+) ([a-z]+)/) {
			$timestamp = $1;
			$format = $2;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			} else {
				if ($matched == 1 || $format eq "short") {
					if ($format eq "short" && $val == -1) {
						$val = 0;
					}
					push @{$self->{_ResultData}},
						[ $timestamp - $start_timestamp,
					  	$val
						];
				}
			}

			$matched = 0;
			$reading = 0;
			$val = 0;
			next;
		}
		if ($reading == 0 && $_ =~ /COMMAND/) {
			$reading = 1;
			next;
		}

		if ($reading) {
			$_ =~ s/^\s+//;
			my @fields = split(/\s+/);
			if ($fields[-1] =~ /$proc/) {
				$matched = 1;
				my $thisVal = $fields[$headingIndex];
				if ($heading eq "TIME") {
					my ($min, $sec) = split(/:/, $thisVal);
					$thisVal = $min * 60 + $sec;
				}
				$val += $thisVal;
			}
		}
	}
}

1;
