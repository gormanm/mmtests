# MonitorProcschedstat.pm
package MMTests::MonitorProcschedstat;
use MMTests::SummariseMonitor;
our @ISA = qw(MMTests::SummariseMonitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorProcschedstat",
	};
	bless $self, $class;
	return $self;
}

my %_fieldNameMap = (
	"ttwu_count"			=> "TTWU Count",
	"ttwu_local"			=> "TTWU Local",
	"sis_search"			=> "SIS Search",
	"sis_domain_search"		=> "SIS Domain Search",
	"sis_scanned"			=> "SIS Scanned",
	"mmtests_sis_domain_scanned"	=> "SIS Domain Scanned",
	"sis_failed"			=> "SIS Failures",
	"mmtests_sis_efficiency"	=> "SIS Search Efficiency",
	"mmtests_sis_domain_efficiency" => "SIS Domain Search Eff",
	"mmtests_sis_fast_success"	=> "SIS Fast Success Rate",
	"mmtests_sis_success"		=> "SIS Success Rate",
);

sub initialise()
{
	my ($self, $subHeading) = @_;

	$self->{_ExactSubheading} = 1;
	$self->{_DataType} = DataTypes::DATA_ACTIONS;
	$self->{_PlotXaxis} = "Time";
	$self->{_PlotYaxes} = \%_fieldNameMap;
	$self->{_DefaultPlot} = "mmtests_sis_efficiency";
	$self->{_PlotType} = "simple";
	$self->SUPER::initialise($subHeading);
}

sub parseSchedstat($) {
	my ($self, $schedstatOutput, $subHeading) = @_;
	my $current_value = 0;
	my $window = $self->{_Window};
	my %current_values;
	my %last_values;
	my $version;

	foreach my $line (split(/\n/, $schedstatOutput)) {
		my @elements = split(/\s/, $line);

		if ($elements[0] eq "version") {
			$version = $elements[1];
			next;
		}
		next if ($elements[0] !~ /^cpu/);

		my ($ttwu_local, $ttwu_count);
		my ($sis_search, $sis_domain_search, $sis_scanned, $sis_failed);
		if ($version == 16) {
			#  0 cpuN
			#  1 tld_count
			#  2 dummy, always 0
			#  3 sched_count
			#  4 sched_goidle
			#  5 ttwu_count
			#  6 ttwu_local
			#  7 rq_cpu_time
			#  8 run_delay
			#  9 pcount
			# 10 sis_search
			# 11 sis_domain_search
			# 12 sis_scanned
			# 13 sis_failed
			$current_values{"ttwu_count"}  += $elements[5];
			$current_values{"ttwu_local"}  += $elements[6];
			$current_values{"sis_search"}  += $elements[10];
			$current_values{"sis_domain_search"}  += $elements[11];
			$current_values{"sis_scanned"} += $elements[12];
			$current_values{"sis_failed"}  += $elements[13];
		} elsif ($version == 15) {
			$current_values{"ttwu_count"}  += $elements[5];
			$current_values{"ttwu_local"}  += $elements[6];
		}
	}

	# Record previous values
	if (defined($self->{_LastValues})) {
		%last_values = %{$self->{_LastValues}};
	}
	$self->{_LastValues} = \%current_values;

	my $sis_search  = $current_values{"sis_search"}  - $last_values{"sis_search"};
	my $sis_domain_search  = $current_values{"sis_domain_search"}  - $last_values{"sis_domain_search"};
	my $sis_scanned = $current_values{"sis_scanned"} - $last_values{"sis_scanned"};
	my $sis_failed = $current_values{"sis_failed"} - $last_values{"sis_failed"};
	my $sis_success = $sis_search - $sis_failed;

	my $fast_search = $sis_search - $sis_domain_search;
	my $domain_scanned = $sis_scanned - $fast_search;

	# mmtests_sis_efficiency
	if ($subHeading eq "mmtests_sis_efficiency") {
		if ($sis_scanned == 0) {
			return 100;
		}
		return $sis_search * 100 / $sis_scanned;
	}

	if ($subHeading eq "mmtests_sis_domain_efficiency") {
		if (!$sis_domain_search) {
			return 100;
		}
		return $sis_domain_search * 100 / $domain_scanned;
	}

	if ($subHeading eq "mmtests_sis_fast_success") {
		if (!$domain_scanned) {
			return 100;
		}
		return $fast_search * 100 / $sis_search;
	}

	if ($subHeading eq "mmtests_sis_success") {
		if ($sis_success) {
			return 100;
		} else {
			return $sis_success * 100 / $sis_search;
		}
	}

	if ($subHeading eq "mmtests_sis_domain_scanned") {
		return $domain_scanned;
	}

	return $current_values{$subHeading} - $last_values{$subHeading};
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my (%schedstat_before, %schedstat_after, %schedstat);
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $start_timestamp = 0;

	if ($subHeading eq "") {
		$subHeading = "mmtests_sis_efficiency";
	}

	my $schedstat = "";
	my $input = $self->SUPER::open_log("$reportDir/proc-schedstat-$testBenchmark");
	while (<$input>) {
		if ($_ =~ /^time: ([0-9]+)/) {
			$timestamp = $1;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			} else {
				my $val = $self->parseSchedstat($schedstat, $subHeading);
				$schedstat = "";
				next if $val == -1;

				$self->addData($subHeading,
					$timestamp - $start_timestamp, $val);
			}
			next;
		}
		$schedstat .= $_;
	}
	close($input);
}

1;
