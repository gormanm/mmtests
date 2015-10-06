# MonitorIostat
package MMTests::MonitorIostat;
use MMTests::Monitor;
use VMR::Stat;
our @ISA = qw(MMTests::Monitor);

use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorIostat",
		_DataType    => MMTests::Monitor::MONITOR_IOSTAT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

my %devices;

my %plotMap = (
	"avgqusz" => "Average Queue Size (requests)",
	"await"   => "Average Wait Time (ms)",
	"r_await" => "Average Read Wait Time (ms)",
	"w_await" => "Average Write Wait Time (ms)",
	"avgrqsz" => "Average Request Size (sectors)",
	"rrqm"    => "Read Requests Merged/sec (req/sec)",
	"wrqm"    => "Write Requests Merged/sec (req/sec)",
	"rkbs"    => "Reads (kb/sec)",
	"wkbs"	  => "Writes (kb/sec)",
	"totalkbs"   => "Total IO (kb/sec)",
);

sub printDataType() {
	my ($self, $subHeading) = @_;
	my $yLabel;

	if (!defined $subHeading) {
		$yLabel = "Await (ms)";
	} else {
		$yLabel = $plotMap{$subHeading};
		if ($yLabel eq "") {
			my @elements = split(/-/, $subHeading);
			$yLabel = $plotMap{$elements[-1]};
		}
	}

	print "Time,Time,$yLabel\n";
}

sub extractSummary() {
	my ($self, $subheading) = @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = 12;
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max" ];
        $self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", ];

	# Yes, this could be done as one pass. Could not be arsed as I'm
	# playing settlers in 10 minutes.
	foreach my $device (sort keys %devices) {
		my (@avgqusz, @avgrqsz, @await, @r_await, @w_await, @svctm, @rrqm, @wrqm, @rkbs, @wkbs, @totalkbs);

		foreach my $rowRef (@data) {
			my @row = @{$rowRef};

			next if ($row[1] ne $device);

			push @avgqusz, $row[2];
			push @await,   $row[3];
			push @r_await, $row[4];
			push @w_await, $row[5];
			push @svctm,   $row[6];
			push @avgrqsz, $row[7];
			push @rrqm,    $row[8];
			push @wrqm,    $row[9];
			push @rkbs,    $row[10];
			push @wkbs,    $row[11];
			push @totalkbs,$row[12];

		}

		my $mean_avgqusz = calc_mean(@avgqusz);
		next if $mean_avgqusz < 0.01;

		push @{$self->{_SummaryData}}, [ "$device-avgqusz",
				 $mean_avgqusz, calc_max(@avgqusz) ];
		push @{$self->{_SummaryData}}, [ "$device-avgrqsz",
				 calc_mean(@avgrqsz), calc_max(@avgrqsz) ];
		push @{$self->{_SummaryData}}, [ "$device-await",
				 calc_mean(@await), calc_max(@await) ];
		push @{$self->{_SummaryData}}, [ "$device-r_await",
			 calc_mean(@r_await), calc_max(@r_await) ];
		push @{$self->{_SummaryData}}, [ "$device-w_await",
			 calc_mean(@w_await), calc_max(@w_await) ];
		push @{$self->{_SummaryData}}, [ "$device-svctm",
				 calc_mean(@svctm), calc_max(@svctm) ];
		push @{$self->{_SummaryData}}, [ "$device-rrqm",
				 calc_mean(@rrqm), calc_max(@rrqm) ];
		push @{$self->{_SummaryData}}, [ "$device-wrqm",
				 calc_mean(@wrqm), calc_max(@wrqm) ];
	}

	return 1;
}

sub printPlot() {
	my ($self) = @_;
	$self->{_FieldFormat}[1] = "";
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $readingDevices = 0;
	my $start_timestamp = 0;
	my $format_type = 1;

	my $file = "$reportDir/iostat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	}

	my $fieldLength = 12;
        $self->{_FieldLength} = $fieldLength;
        $self->{_FieldHeaders} = [ "Time", "Device", "AvgQueueSz", "AWait", "R_AWait", "W_AWait", "SVCtm", "AvgRqSz", "Rrqm", "Wrqm", "Rkbs", "Wkbs", "Totalkbs" ];
        $self->{_FieldFormat} = [ "%${fieldLength}.4f", "%${fieldLength}s",
				  "%${fieldLength}.2f", "%${fieldLength}.2f",
				  "%${fieldLength}.2f", "%${fieldLength}.2f",
				  "%${fieldLength}.2f", "%${fieldLength}.2f",
				  "%${fieldLength}.2f", "%${fieldLength}.2f",
				  "%${fieldLength}.2f", "%${fieldLength}.2f" ];

	my %samples;

	while (<INPUT>) {
		my @elements = split (/\s+/, $_);
		my $timestamp = $elements[1];
		if ($start_timestamp == 0) {
			$start_timestamp = $timestamp;
		}
		$timestamp -= $start_timestamp;

		if ($elements[5] eq "Device:") {
			if ($elements[10] eq "rsec/s") {
				$format_type = 0;
			}
			$readingDevices = 1;
			next;
		}
		if (!$readingDevices) {
			next;
		}
		if ($elements[5] eq "") {
			$readingDevices = 0;
			next;
		}

		# Filter out completely idle devices
		if ($elements[13] == 0 &&
		    $elements[14] == 0 && $elements[15] == 0) {
			next;
		}
		if ($elements[13] > 1) {
			$devices{$elements[5]} = 1;
		}
		if (!$devices{$elements[5]}) {
			next;
		}

		# Record times
		my ($avgqusz, $avgrqsz, $await, $r_await, $w_await, $svctm, $rrqm, $wrqm, $rkbs, $wkbs, $totalkbs);
		if ($format_type == 0) {
			$rrqm = $elements[6];
			$wrqm = $elements[7];
			$rkbs = $elements[10];
			$wkbs = $elements[11];
			$totalkbs = $rkbs + $wkbs;
			$avgrqsz = $elements[12];
			$avgqusz = $elements[13];
			$await = $elements[14];
			$r_await = -1;
			$w_await = -1;
			$svctm = $elements[15];
		} elsif ($format_type == 1) {
			$rrqm = $elements[6];
			$wrqm = $elements[7];
			$rkbs = $elements[10];
			$wkbs = $elements[11];
			$totalkbs = $rkbs + $wkbs;
			$avgrqsz = $elements[12];
			$avgqusz = $elements[13];
			$await = $elements[14];
			$r_await = $elements[15];
			$w_await = $elements[16];
			$svctm = $elements[17];
		}

		# Filter out insane values
		if ($avgqusz > 1000000 ||
		    $await > 3600000 ||
		    $r_await > 3600000 ||
		    $w_await > 3600000) {
			next;
		}

		$samples{$elements[5]}++;
		if ($samples{$elements[5]} == 1) {
			next;
		}

		if ($subHeading eq "") {
			# Pushing time avgqu-sz await r_await w_await push
			push @{$self->{_ResultData}}, [ $timestamp, $elements[5],
					$avgqusz, $await, $r_await, $w_await,
					$svctm, $avgrqsz, $rrqm, $wrqm ];
		} else {
			if ($subHeading eq "$elements[5]-avgqusz") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $avgqusz ];
			} elsif ($subHeading eq "$elements[5]-avgrqsz") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $avgrqsz ];
			} elsif ($subHeading eq "$elements[5]-await") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $await ];
			} elsif ($subHeading eq "$elements[5]-r_await") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $r_await ];
			} elsif ($subHeading eq "$elements[5]-w_await") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $w_await ];
			} elsif ($subHeading eq "$elements[5]-svctm") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $svctm ];
			} elsif ($subHeading eq "$elements[5]-rrqm") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $rrqm ];
			} elsif ($subHeading eq "$elements[5]-wrqm") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $wrqm ];
			} elsif ($subHeading eq "$elements[5]-rkbs") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $rkbs ];
			} elsif ($subHeading eq "$elements[5]-wkbs") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $wkbs ];
			} elsif ($subHeading eq "$elements[5]-totalkbs") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[5], $totalkbs ];
			}
		}
	} close INPUT;
}

1;
