# MonitorTurbostat.pm
package MMTests::MonitorTurbostat;
use MMTests::SummariseMonitor;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMonitor);
use strict;

my %headings = (
	"CorWatt" => "Core Watts",
	"PkgWatt" => "Package Watts",
	"CPU%c0"  => "C0 Hardware Percent",
	"CPU%c1"  => "C1 Hardware Percent",
	"CPU%c2"  => "C2 Hardware Percent",
	"CPU%c3"  => "C3 Hardware Percent",
	"CPU%c4"  => "C4 Hardware Percent",
	"CPU%c5"  => "C5 Hardware Percent",
	"CPU%c6"  => "C6 Hardware Percent",
	"CPU%c7"  => "C7 Hardware Percent",
	"CPU%c8"  => "C8 Hardware Percent",
	"CPU%c9"  => "C9 Hardware Percent",
	"Busy%"   => "Busy Percent",
	"%Busy"   => "Busy Percent",
	"Avg_MHz" => "Average Frequency (MHz)",
);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "MonitorTurbostat";
	$self->{_PlotType} = "simple";
	$self->{_DefaultPlot} = "Avg_MHz";
	$self->{_ExactSubheading} = 1;
	$self->{_PlotYaxes} = \%headings;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir, $testBenchmark, $subHeading) = @_;
	my $timestamp;
	my $start_timestamp = 0;
	my $input;
	my %_colMap;
	my @fieldHeaders;

	# Discover column header names
	$input = $self->SUPER::open_log("$reportDir/turbostat-$testBenchmark");
	while (!eof($input)) {
		my $line = <$input>;
		next if ($line !~ /\s+Core\s+CPU/ && $line !~ /\s+CPU\s+Avg_MHz/);
		$line =~ s/^\s+//;
		my @elements = split(/\s+/, $line);

		my $index;
		foreach my $header (@elements) {
			if ($header =~ /CPU%c[0-9]/ ||
			    $header =~ /C[0-9]%/ ||
			    $header =~ /C[0-9][A-Z]*%/ ||
			    $header eq "CorWatt" ||
			    $header eq "PkgWatt" ||
			    $header eq "%Busy" ||
			    $header eq "POLL%" ||
			    $header eq "Busy%" ||
			    $header eq "Avg_MHz") {
				$_colMap{$header} = $index;
			}

			$index++;
		}
		last;
	}
	close($input);
	@fieldHeaders = sort keys %_colMap;

	# Fill in the headers
	if ($subHeading ne "") {
		if (!defined $_colMap{$subHeading}) {
			die("Unrecognised heading $subHeading");
		}
	}

	# Read all counters
	my $timestamp = 0;
	my $start_timestamp = 0;
	my $offset;
	$input = $self->SUPER::open_log("$reportDir/turbostat-$testBenchmark");
	while (!eof($input)) {
		my $line = <$input>;

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
	close($input);
}

1;
