# MonitorVmstat.pm
package MMTests::MonitorVmstat;
use MMTests::SummariseMonitor;
our @ISA = qw(MMTests::SummariseMonitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorVmstat",
		_ExactSubheading  => 1,
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
	"ussy"      => 17,
	"totalcpu"  => 18,
	"pfree" => 99,
);

use constant typeMap => {
	"r"	=> DataTypes::DATA_ACTIONS,
	"b"	=> DataTypes::DATA_ACTIONS,
	"swpd"	=> DataTypes::DATA_SIZE_PAGES,
	"free"	=> DataTypes::DATA_SIZE_MBYTES,
	"buff"	=> DataTypes::DATA_SIZE_KBYTES,
	"cache"	=> DataTypes::DATA_SIZE_KBYTES,
	"si"	=> DataTypes::DATA_KBYTES_PER_SECOND,
	"so"	=> DataTypes::DATA_KBYTES_PER_SECOND,
	"bi"	=> DataTypes::DATA_KBYTES_PER_SECOND,
	"bo"	=> DataTypes::DATA_KBYTES_PER_SECOND,
	"in"	=> DataTypes::DATA_ACTIONS_PER_SECOND,
	"cs"	=> DataTypes::DATA_ACTIONS_PER_SECOND,
	"us"	=> DataTypes::DATA_USAGE_PERCENT,
	"sy"	=> DataTypes::DATA_USAGE_PERCENT,
	"id"	=> DataTypes::DATA_USAGE_PERCENT,
	"wa"	=> DataTypes::DATA_USAGE_PERCENT,
	"st"	=> DataTypes::DATA_USAGE_PERCENT,
	"ussy"	=> DataTypes::DATA_RATIO_SPEEDUP,
	"totalcpu" => DataTypes::DATA_USAGE_PERCENT,
};

use constant headings => {
	"r"	=> "Runnable Processes",
	"b"	=> "Blocked Processes",
	"swpd"	=> "Swap usage (pages)",
	"free"	=> "Free Memory (mb)",
	"si"	=> "Swap Ins",
	"so"	=> "Swap Outs",
	"in"	=> "Interrupts",
	"cs"	=> "Context Switches",
	"us"	=> "%age CPU User",
	"sy"	=> "%age CPU System",
	"id"	=> "%age CPU Idle",
	"wa"	=> "%age CPU Blocked",
	"ussy"	=> "User/Kernel Ratio",
	"totalcpu" => "Total CPU Usage",
};

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_DataTypes} = typeMap;
	$self->{_PlotXaxis} = "Time";
	$self->{_PlotYaxes} = headings;
	$self->{_PlotType} = "simple";
	$self->SUPER::initialise($subHeading);
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $start_timestamp = 0;

	if ($subHeading eq "") {
		$subHeading = "sy";
	}
	if (!defined $_colMap{$subHeading}) {
		die("Unrecognised heading $subHeading");
	}
	my $headingIndex = $_colMap{$subHeading};

	my $total_memory_kb;
	my $file = "$reportDir/tests-sysstate.gz";
	open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	while (<INPUT>) {
		if ($_ =~ /^MemTotal: ([0-9])* kB/) {
			$total_memory_kb = $1;
			last;
		}
	}
	close INPUT;

	$file = "$reportDir/vmstat-$testBenchmark";
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

		my $val;
		if ($subHeading eq "ussy") {
			# User/Kernel ratio
			my $userCPU = $fields[$_colMap{"us"}];
			my $sysCPU = $fields[$_colMap{"sy"}];

			if ($sysCPU == 0 && $userCPU == 0) {
				$val = 0;
			} else {
				$val = $userCPU / ($userCPU + $sysCPU);
			}
		} elsif ($subHeading eq "totalcpu") {
			$val = $fields[$_colMap{"us"}] + $fields[$_colMap{"sy"}];
		} elsif ($subHeading eq "pfree") {
			$val = $fields[$_colMap{"free"}] * 100 / $total_memory_kb;
		} else {
			$val = $fields[$headingIndex];
			if ($headingIndex == 3) {
				$val /= 1024;
			}
			if ($headingIndex >= 12 && $headingIndex <= 16) {
				$val = 100 if ($val > 100);
			}
		}

		$self->addData($subHeading, $timestamp - $start_timestamp, $val );
	}
}

1;
