# MonitorIostat
package MMTests::MonitorIostat;
use MMTests::SummariseMonitor;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMonitor);

use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "MonitorIostat";
	$self->{_PlotType} = "simple";
	$self->{_DefaultPlot} = "sda-await";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

my %devices;

my %typeMap = (
	"avgqusz" => DataTypes::DATA_SIZE_QUEUED,
	"await"   => DataTypes::DATA_TIME_MSECONDS,
	"r_await" => DataTypes::DATA_TIME_MSECONDS,
	"w_await" => DataTypes::DATA_TIME_MSECONDS,
	"avgrqsz" => DataTypes::DATA_SIZE_SECTOR,
	"rrqm"    => DataTypes::DATA_REQ_PER_SECOND,
	"wrqm"    => DataTypes::DATA_REQ_PER_SECOND,
	"rkbs"    => DataTypes::DATA_KBYTES_PER_SECOND,
	"wkbs"	  => DataTypes::DATA_KBYTES_PER_SECOND,
	"totalkbs" => DataTypes::DATA_KBYTES_PER_SECOND,
	"svctm"   => DataTypes::DATA_TIME_MSECONDS,
);

sub getDataType() {
	my ($self, $op) = @_;
	my @elements = split(/-/, $op);

	return $typeMap{$elements[1]};
}

sub extractReport($$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $readingDevices = 0;
	my $start_timestamp = 0;
	my $format_type = -1;
	my $input;

	$input = $self->SUPER::open_log("$reportDir/iostat-$testBenchmark");

	my $fieldLength = 12;
        $self->{_FieldLength} = $fieldLength;
        $self->{_FieldFormat} = [ "%${fieldLength}.4f", "%${fieldLength}.2f" ];

	my %samples;
	while (<$input>) {
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
			foreach my $op ("avgqusz", "await", "r_await",
			  "w_await", "svctm", "avgrqsz", "rrqm", "wrqm") {
				$self->addData("$dev-$op", $timestamp, $iostat{$op});
			}
		} else {
			my @elements = split(/-/, $subHeading);
			if ($elements[0] eq $dev) {
				$self->addData("$subHeading", $timestamp, $iostat{$elements[1]});
			}
		}
	}

	close($input);
}

1;
