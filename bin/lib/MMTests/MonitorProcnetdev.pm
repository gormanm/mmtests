# MonitorProcnetdev.pm
package MMTests::MonitorProcnetdev;
use MMTests::Monitor;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorProcnetdev",
		_DataType      => MMTests::Monitor::MONITOR_PROCNETDEV,
		_MultiopMonitor => 1
	};
	bless $self, $class;
	return $self;
}

my %_colMap = (
	"interface"	=> 0,
	"rbytes"	=> 1,
	"rpackets"	=> 2,
	"rerrs"		=> 3,
	"rdrop"		=> 4,
	"rfifo"		=> 5,
	"rframe"	=> 6,
	"rcompressed"	=> 7,
	"rmulticast"	=> 8,
	"tbytes"	=> 9,
	"tpackets"	=> 10,
	"terrs"		=> 11,
	"tdrop"		=> 12,
	"tfifo"		=> 13,
	"tcolls"	=> 14,
	"tcarrier"	=> 15,
	"tcompressed"	=> 16,
);

sub printDataType() {
	my ($self) = @_;
	my $headingIndex = $self->{_HeadingIndex};

	if ($headingIndex == 1) {
		print "Netdev,Time,Received Bytes\n";
	} elsif ($headingIndex == 2){
		print "Netdev,Time,Received Packets\n";
	} elsif ($headingIndex == 9){
		print "Netdev,Time,Transmitted Bytes\n";
	} elsif ($headingIndex == 10){
		print "Netdev,Time,Transmitted Packets\n";
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
	my $current_value = 0;

	if ($subHeading eq "") {
		die("Unrecognised heading");
	}

	my ($interface, $field) = split(/-/, $subHeading);

	if (!defined $_colMap{$field}) {
		die("Unrecognised heading");
	}

	my $headingIndex = $_colMap{$field};
	$self->{_HeadingIndex} = $headingIndex;

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "Op", "Time", "Value" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}d", "%${fieldLength}d" ];

	my $file = "$reportDir/proc-net-dev-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	while (<INPUT>) {
		if ($_ =~ /^time: ([0-9]+)/) {
			$timestamp = $1;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
		} else {
			$_ =~ s/^\s+//;
			my @fields = split(/\s+/, $_);

			if ($interface eq $fields[%_colMap{"interface"}]) {
				my $delta;

				if ($current_value == 0) {
					$current_value = $fields[%_colMap{$field}];
					$delta = 0;
				} else {
					$delta = $fields[%_colMap{$field}] - $current_value;
					$current_value = $fields[%_colMap{$field}];
				}

				$self->addData($subHeading,
					  $timestamp - $start_timestamp,
					  $delta);
			}
		}
	}
}

1;
