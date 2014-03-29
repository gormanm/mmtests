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
my $format_type = 1;

sub printDataType() {
	my ($self) = @_;

	print "Time,Time,Await (ms)\n";
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
		my (@avgqz, @await, @r_await, @w_await);

		foreach my $rowRef (@data) {
			my @row = @{$rowRef};

			next if ($row[1] ne $device);

			push @avgqz,   $row[2];
			push @await,   $row[3];
			push @r_await, $row[4];
			push @w_await, $row[5];
		}

		my $mean_avgqz = calc_mean(@avgqz);
		next if $mean_avgqz < 0.01;

		push @{$self->{_SummaryData}}, [ "$device-avgqz",
				 $mean_avgqz, calc_max(@avgqz) ];
		push @{$self->{_SummaryData}}, [ "$device-await",
				 calc_mean(@await), calc_max(@await) ];
		if ($format_type == 1) {
			push @{$self->{_SummaryData}}, [ "$device-r_await",
				 calc_mean(@r_await), calc_max(@r_await) ];
			push @{$self->{_SummaryData}}, [ "$device-w_await",
				 calc_mean(@w_await), calc_max(@w_await) ];
		}
	}

	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $readingDevices = 0;
	my $start_timestamp = 0;

	my $file = "$reportDir/iostat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	}

	my $fieldLength = 12;
        $self->{_FieldLength} = $fieldLength;
        $self->{_FieldHeaders} = [ "Time", "Device", "Queue", "AWait", "R_AWait", "W_AWait" ];
        $self->{_FieldFormat} = [ "%${fieldLength}.4f", "%${fieldLength}s",
				  "%${fieldLength}.2f", "%${fieldLength}.2f",
				  "%${fieldLength}.2f", "%${fieldLength}.2f" ];

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

		if ($elements[5] == 0 && $elements[13] == 0 &&
		    $elements[14] == 0 && $elements[15] == 0) {
			next;
		}

		$devices{$elements[5]} = 1;
		my ($avgqz, $await, $r_await, $w_await);
		if ($format_type == 0) {
			$avgqz = $elements[13];
			$await = $elements[14];
			$r_await = 0;
			$w_await = 0;
		} elsif ($format_type == 1) {
			$avgqz = $elements[13];
			$await = $elements[14];
			$r_await = $elements[15];
			$w_await = $elements[16];
		}

		if ($subHeading eq "") {
			# Pushing time avgqu-sz await r_await w_await
			push @{$self->{_ResultData}}, [ $timestamp, $elements[5], 
					$elements[13],
					$elements[14], $elements[15], $elements[16] ];
		} else {
			if ($subHeading eq "$elements[5]-avgqz") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[13] ];
			} elsif ($subHeading eq "$elements[5]-await") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[14] ];
			} elsif ($subHeading eq "$elements[5]-r_await") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[15] ];
			} elsif ($subHeading eq "$elements[5]-w_await") {
				push @{$self->{_ResultData}}, [ $timestamp, $elements[16] ];
			}
		}
	}
	close INPUT;
}

1;
