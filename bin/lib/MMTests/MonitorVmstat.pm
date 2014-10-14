# MonitorVmstat.pm
package MMTests::MonitorVmstat;
use MMTests::Monitor;
use VMR::Report;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorVmstat",
		_DataType      => MMTests::Monitor::MONITOR_VMSTAT,
		_RowOrientated => 1,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

my %_colMap = (
	"r"	=> 0,
	"b"	=> 1,
	"swpd"	=> 2,
	"free"	=> 3,
	"buff"	=> 4,
	"cache"	=> 5,
	"si"	=> 6,
	"so"	=> 7,
	"bi"	=> 8,
	"bo"	=> 9,
	"in"	=> 10,
	"cs"	=> 11,
	"us"	=> 12,
	"sy"	=> 13,
	"id"	=> 14,
	"wa"	=> 15,
	"st"	=> 16,
);

sub printDataType() {
	my ($self) = @_;
	my $headingIndex = $self->{_HeadingIndex};

	if ($headingIndex == 2) {
		print "Pages,Time,Swap usage (pages)\n";
	} elsif ($headingIndex == 3) {
		print "Time,Time,Free Memory (mb)\n";
	} elsif ($headingIndex == 6) {
		print "Time,Time,Swap Ins";
	} elsif ($headingIndex == 7) {
		print "Time,Time,Swap Outs";
	} elsif ($headingIndex == 10) {
		print "Time,Time,Interrupts\n";
	} elsif ($headingIndex == 11) {
		print "CPUUsage,Time,Context Switches\n";
	} elsif ($headingIndex == 12) {
		print "CPUUsage,Time,%age CPU User\n";
	} elsif ($headingIndex == 13) {
		print "CPUUsage,Time,%age CPU System\n";
	} elsif ($headingIndex == 14) {
		print "CPUUsage,Time,%age CPU Idle\n";
	} elsif ($headingIndex == 15) {
		print "CPUUsage,Time,%age CPU Blocked\n";
	} else {
		print "Unknown\n";
	}
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $start_timestamp = 0;

	if ($subHeading eq "") {
		$subHeading = "sy";
	}
	if (!defined $_colMap{$subHeading}) {
		die("Unrecognised heading");
	}
	my $headingIndex = $_colMap{$subHeading};
	$self->{_HeadingIndex} = $headingIndex;

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "time", $subHeading ];
	$self->{_FieldFormat} = [ "%${fieldLength}f", "%${fieldLength}d" ];

	my $file = "$reportDir/vmstat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	my $matched;
	my $reading;
	my $timestamp = 0;
	my $val = -1;
	while (<INPUT>) {
		my ($timing, $details);
		if ($_ =~ /--/) {
			($timing, $details) = split(/--/, $_);
			my $dummy;

			$timing =~ s/^\s+//;
			$details =~ s/^\s+//;
			($timestamp, $dummy) = split(/\s+/, $timing);
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
		} else {
			$timestamp++;
			$details = $_;
		}

		my @fields = split(/\s+/, $details);
		my $val = $fields[$headingIndex];
		if ($headingIndex == 3) {
			$val /= 1024;
		}
		push @{$self->{_ResultData}},
			[ $timestamp - $start_timestamp,
		  	  $val
			];
	}
}

1;
