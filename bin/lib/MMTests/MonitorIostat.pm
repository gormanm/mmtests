# MonitorIostat
package MMTests::MonitorIostat;
use MMTests::Monitor;
use MMTests::Stat;
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
	my $format_type = -1;

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

		# format 0: Device:         rrqm/s   wrqm/s     r/s     w/s   rsec/s   wsec/s avgrq-sz avgqu-sz   await  svctm  %util
		# format 1: Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
		# format 2: Device            r/s     w/s     rkB/s     wkB/s   rrqm/s   wrqm/s  %rrqm  %wrqm r_await w_await aqu-sz rareq-sz wareq-sz  svctm  %util
		if ($elements[5] =~ /Device/) {
			if ($format_type == -1) {
				if ($elements[6] eq "rrqm/s") {
					if ($elements[10] eq "rsec/s") {
						$format_type = 0;
					}
					if ($elements[10] eq "rkB/s") {
						$format_type = 1;
					}
				}
				if ($elements[6] eq "r/s" && $elements[10]) {
					$format_type = 2;
				}
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
		my ($dev, %iostat);
		$dev = $elements[5];
		if ($format_type == 0) {
			# format 0: Device:         rrqm/s   wrqm/s     r/s     w/s   rsec/s   wsec/s avgrq-sz avgqu-sz   await  svctm  %util
			$iostat{"rrqm"} = $elements[6];
			$iostat{"wrqm"} = $elements[7];
			$iostat{"rkbs"} = $elements[10];
			$iostat{"wkbs"} = $elements[11];
			$iostat{"totalkbs"} = $iostat{"rkbs"} + $iostat{"wkbs"};
			$iostat{"avgrqsz"} = $elements[12];
			$iostat{"avgqusz"} = $elements[13];
			$iostat{"await"} = $elements[14];
			$iostat{"r_await"} = -1;
			$iostat{"w_await"} = -1;
			$iostat{"svctm"} = $elements[15];
		} elsif ($format_type == 1) {
			# format 1: Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
			$iostat{"rrqm"} = $elements[6];
			$iostat{"wrqm"} = $elements[7];
			$iostat{"rkbs"} = $elements[10];
			$iostat{"wkbs"} = $elements[11];
			$iostat{"totalkbs"} = $iostat{"rkbs"} + $iostat{"wkbs"};
			$iostat{"avgrqsz"} = $elements[12];
			$iostat{"avgqusz"} = $elements[13];
			$iostat{"await"} = $elements[14];
			$iostat{"r_await"} = $elements[15];
			$iostat{"w_await"} = $elements[16];
			$iostat{"svctm"} = $elements[17];
		} elsif ($format_type == 2) {
			#           5                 6       7       8         9       10       11      12     13    14      15      16     17       18        19     20
			# format 2: Device            r/s     w/s     rkB/s     wkB/s   rrqm/s   wrqm/s  %rrqm  %wrqm r_await w_await aqu-sz rareq-sz wareq-sz  svctm  %util
			$iostat{"rrqm"} = $elements[10];
			$iostat{"wrqm"} = $elements[11];
			$iostat{"rkbs"} = $elements[8];
			$iostat{"wkbs"} = $elements[9];
			$iostat{"totalkbs"} = $iostat{"rkbs"} + $iostat{"wkbs"};
			$iostat{"avgqusz"} = $elements[16];
			$iostat{"r_await"} = $elements[14];
			$iostat{"w_await"} = $elements[15];
			$iostat{"svctm"} = $elements[19];

			# Approximations :(
			$iostat{"await"} = ($iostat{"r_await"} + $iostat{"w_await"}) / 2;
			$iostat{"avgrqsz"} = ($elements[17] + $elements[18]) / 2;
		}

		# Filter out insane values
		if ($iostat{"avgqusz"} > 1000000 ||
		    $iostat{"await"} > 3600000 ||
		    $iostat{"r_await"} > 3600000 ||
		    $iostat{"w_await"} > 3600000) {
			next;
		}

		$samples{$dev}++;
		if ($samples{$dev} == 1) {
			next;
		}

		if ($subHeading eq "") {
			# Pushing time avgqu-sz await r_await w_await push
			push @{$self->{_ResultData}}, [ $timestamp, $dev,
					$iostat{"avgqusz"}, $iostat{"await"},
					$iostat{"r_await"}, $iostat{"w_await"},
					$iostat{"svctm"}, $iostat{"avgrqsz"},
					$iostat{"rrqm"}, $iostat{"wrqm"} ];
		} else {
			my @elements = split(/-/, $subHeading);
			if ($elements[0] eq $dev) {
				push @{$self->{_ResultData}}, [ $timestamp, $dev, $iostat{$elements[1]} ];
			}
		}
	} close INPUT;
}

1;
