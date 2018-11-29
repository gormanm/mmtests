# MonitorTurbostat.pm
package MMTests::MonitorTurbostat;
use MMTests::Monitor;
use MMTests::Stat;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorTurbostat",
		_DataType      => MMTests::Monitor::MONITOR_PERFTIMESTAT,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

my %_colMap;
my @fieldHeaders;

sub printDataType() {
	my ($self, $subHeading) = @_;

	if ($subHeading eq "CorWatt" || $subHeading eq "PkgWatt") {
		print "Watt,Time,Watt";
	} else {
		print "Percentage,Time,Percentage";
	}
}

sub printPlot() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractSummary() {
	my ($self, $subheading) = @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = 18;
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", ];

	# Array of potential headers and the samples
	shift @fieldHeaders;
	my @headerCounters;
	my $index = 1;
	$headerCounters[0] = [];
	foreach my $header (@fieldHeaders) {
		next if $index == 0;
		$headerCounters[$index] = [];
		$index++;
	}

	# Collect the samples
	foreach my $rowRef (@data) {
		my @row = @{$rowRef};

		$index = 1;
		foreach my $header (@fieldHeaders) {
			next if $index == 0;
			push @{$headerCounters[$index]}, $row[$index];
			$index++;
		}
	}

	# Summarise
	$index = 1;
	foreach my $header (@fieldHeaders) {
		push @{$self->{_SummaryData}}, [ "$header",
			 calc_mean(@{@headerCounters[$index]}), calc_max(@{@headerCounters[$index]}) ];

		$index++;
	}

	return 1;
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $timestamp;
	my $start_timestamp = 0;

	# Discover column header names
	my $file = "$reportDir/turbostat-$testName-$testBenchmark";
	if (scalar keys %_colMap == 0) {
		if (-e $file) {
			open(INPUT, $file) || die("Failed to open $file: $!\n");
		} else {
			$file .= ".gz";
			open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
		}
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			next if ($line !~ /\s+Core\s+CPU/ && $line !~ /\s+CPU\s+Avg_MHz/);
			$line =~ s/^\s+//;
			my @elements = split(/\s+/, $line);

			my $index;
			foreach my $header (@elements) {
				if ($header =~ /CPU%c[0-9]/ ||
				    $header eq "CorWatt" ||
				    $header eq "PkgWatt" ||
				    $header eq "%Busy" ||
				    $header eq "Busy%" ||
				    $header eq "Avg_MHz") {
					$_colMap{$header} = $index;
				}

				$index++;
			}
			last;
		}
		close(INPUT);
		@fieldHeaders = sort keys %_colMap;
	}
	unshift @fieldHeaders, "Time";

	# Fill in the headers
	if ($subHeading ne "") {
		$self->{_FieldHeaders}  = [ "", "$subHeading" ];
		if (!defined $_colMap{$subHeading}) {
			die("Unrecognised heading $subHeading");
		}
		my $headingIndex = $_colMap{$subHeading};
		$self->{_HeadingIndex} = $_colMap{$subHeading};
		$self->{_HeadingName} = $subHeading;
	} else {
		$self->{_FieldHeaders}  = \@fieldHeaders;
	}

	# Read all counters
	$file = "$reportDir/turbostat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}
	my $reading = 0;
	my $timestamp;
	my $start_timestamp = 0;
	my @row;
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		$line =~ s/^\s+//;
		my @elements = split(/\s+/, $line);

		if ($line =~ /Core\s+CPU/ || $line =~ /CPU\s+Avg_MHz/) {
			if ($start_timestamp) {
				push @{$self->{_ResultData}}, [ @row ];
				$#row = -1;
			}

			$reading = 0;
			if ($elements[3] eq "--") {
				$timestamp = $elements[0];
				if ($start_timestamp == 0) {
					$start_timestamp = $elements[0];
				}
			} else {
				$timestamp++;
				if ($start_timestamp == 0) {
					$timestamp = $start_timestamp = 1;
				}
			}
			push @row, $timestamp - $start_timestamp;
		}

		if ($line =~ /Core\s+CPU/ || $line =~ /CPU\s+Avg_MHz/) {
			$reading = 1;
			next;
		}
		next if $reading != 1;
		my $offset = 0;
		if ($elements[3] eq "--") {
			$offset = 4;
		}
		next if @elements[$offset] ne "-" && @elements[$offset] ne "-";

		foreach my $header (@fieldHeaders) {
			next if ($header eq "Time");
			if ($subHeading eq "" || $header eq $subHeading) {
				push @row, $elements[$_colMap{$header}];
			}
		}
	}
	close(INPUT);
}

1;
