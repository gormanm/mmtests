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
	my ($self, $subHeading) = @_;
	my %data = %{$self->dataByOperation()};

	if ($subHeading eq "") {
		$subHeading = "Avg_MHz";
	}
	$self->{_PrintHandler}->printRow($data{"$subHeading"}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractSummary() {
	my ($self, $subheading) = @_;
	my %data = %{$self->dataByOperation()};

	my $fieldLength = 18;
	$self->{_SummaryHeaders} = [ "Statistic", "Mean", "Max" ];
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.2f", ];

	foreach my $header (@fieldHeaders) {
		my @units;

		foreach my $row (@{$data{$header}}) {
			push @units, @{$row}[1];
		}

		push @{$self->{_SummaryData}}, [ "$header",
			 calc_mean(@units), calc_max(@units) ];
	}

	return 1;
}

sub extractReport() {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading) = @_;
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

	# Fill in the headers
	if ($subHeading ne "") {
		if (!defined $_colMap{$subHeading}) {
			die("Unrecognised heading $subHeading");
		}
		$self->{_FieldHeaders}  = [ "Op", "Time", "$subHeading" ];
	} else {
		$self->{_FieldHeaders}  = [ "Op", "Time", "Value" ];
	}

	# Read all counters
	$file = "$reportDir/turbostat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}
	my $timestamp = 0;
	my $start_timestamp = 0;
	my $offset;
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		$line =~ s/^\s+//;
		my @elements = split(/\s+/, $line);

		# Monitor in with timestamps prepended?
		if ($elements[3] eq "--") {
			$offset = 4;
		} else {
			$offset = 0;
		}
		# We gather data only from the turbostat summary line
		next if $elements[$offset] ne "-";

		if ($elements[3] eq "--") {
			$timestamp = $elements[0];
		} else {
			$timestamp++;
		}
		if ($start_timestamp == 0) {
			$start_timestamp = $timestamp;
		}
		foreach my $header (@fieldHeaders) {
			if ($subHeading eq "" || $header eq $subHeading) {
				$self->addData($header,
					$timestamp - $start_timestamp,
					$elements[$_colMap{$header}]);
			}
		}
	}
	close(INPUT);
}

1;
