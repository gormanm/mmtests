# MonitorMmtestsschedstat.pm
package MMTests::MonitorMmtestsschedstat;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName	=> "Mmtestsschedstat",
		_PlotYaxis	=> "Actions",
		_FieldLength	=> 15,
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
	"sis_recent_hit"		=> "SIS Recent Used Hit",
	"sis_recent_miss"		=> "SIS Recent Used Miss",
	"mmtests_sis_domain_scanned"	=> "SIS Domain Scanned",
	"sis_failed"			=> "SIS Failures",
	"sis_core_search"		=> "SIS Core Search",
	"mmtests_sis_core_hit"		=> "SIS Core Hit",
	"sis_core_miss"			=> "SIS Core Miss",
	"mmtests_sis_efficiency"	=> "SIS Search Efficiency",
	"mmtests_sis_domain_efficiency"	=> "SIS Domain Search Eff",
	"mmtests_sis_core_efficiency"	=> "SIS Core Search Eff",
	"mmtests_sis_fast_success"	=> "SIS Fast Success Rate",
	"mmtests_sis_success"		=> "SIS Success Rate",
	"mmtests_sis_recent_success"	=> "SIS Recent Success Rate",
	"mmtests_sis_recent_attempts"	=> "SIS Recent Attempts",
);

my @_fieldOrder = (
	"ttwu_count",
	"ttwu_local",
	"sis_search",
	"sis_domain_search",
	"sis_scanned",
	"mmtests_sis_domain_scanned",
	"sis_failed",
	"sis_core_search",
	"mmtests_sis_core_hit",
	"sis_core_miss",
	"sis_recent_hit",
	"sis_recent_miss",
	"mmtests_sis_recent_attempts",
	"mmtests_sis_efficiency",
	"mmtests_sis_domain_efficiency",
	"mmtests_sis_fast_success",
	"mmtests_sis_success",
	"mmtests_sis_recent_success",
);

sub extractReport($$$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my (%schedstat_before, %schedstat_after, %schedstat);
	my ($reading_test, $reading_before, $reading_after);
	my $version;

	foreach my $key (keys @_fieldOrder) {
		$schedstat_before{$key} = 0;
		$schedstat_after{$key} = 0;
	}

	(my $testBenchmarkRegex = $testBenchmark) =~ s/\+/\\+/g;
	my $input = $self->SUPER::open_log("$reportDir/tests-sysstate");
	while (<$input>) {
		if ($_ =~ /^test begin \:\: $testBenchmarkRegex/) {
			$reading_test = 1;
			next;
		}

		if ($reading_test) {
			if ($_ =~ /^file start :: \/proc\/schedstat/) {
				$reading_before = 1;
				next;
			}

			if ($_ =~ /^file start :: \/proc\/diskstats/) {
				$reading_before = 0;
				next;
			}

			if ($_ =~ /^file end :: \/proc\/schedstat/) {
				$reading_after = 1;
				next;
			}

			if ($_ =~ /^file end :: \/proc\/diskstats/) {
				$reading_after = 0;
				next;
			}
			next if (!$reading_before && !$reading_after);

			my @elements = split(/\s/, $_);
			if ($elements[0] eq "version") {
				$version = $elements[1];
				next;
			}
			next if ($elements[0] !~ /^cpu/);

			my ($ttwu_local, $ttwu_count);
			my ($sis_search, $sis_domain_search, $sis_scanned, $sis_failed);
			my ($sis_recent_hit, $sis_recent_miss);
			my ($sis_core_search, $sis_core_hit, $sis_core_miss);
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
			# 14 sis_recent_hit
			# 15 sis_recent_miss
			# 16 sis_core_search
			# 17 sis_core_miss
			if ($version >= 15) {
				$ttwu_count = $elements[5];
				$ttwu_local = $elements[6];
				$sis_search  = 0;
				$sis_domain_search = 0;
				$sis_scanned = 0;
				$sis_failed = 0;
				$sis_recent_hit = 0;
				$sis_recent_miss = 0;
				$sis_core_search = 0;
				$sis_core_hit = 0;
				$sis_core_miss = 0;
			}
			if ($version >= 16) {
				$sis_search  = $elements[10];
				$sis_domain_search = $elements[11];
				$sis_scanned = $elements[12];
				$sis_failed = $elements[13];
			}
			if ($version >= 17) {
				$sis_recent_hit = $elements[14];
				$sis_recent_miss = $elements[15];
			}
			if ($version >= 18) {
				$sis_core_search = $elements[16];
				$sis_core_miss = $elements[17];
				$sis_core_hit = $sis_core_search - $sis_core_miss;
			}

			if ($reading_before) {
				$schedstat_before{"ttwu_count"}  += $ttwu_count;
				$schedstat_before{"ttwu_local"}  += $ttwu_local;
				$schedstat_before{"sis_search"}  += $sis_search;
				$schedstat_before{"sis_domain_search"}  += $sis_domain_search;
				$schedstat_before{"sis_scanned"} += $sis_scanned;
				$schedstat_before{"sis_failed"}  += $sis_failed;
				$schedstat_before{"sis_recent_hit"} += $sis_recent_hit;
				$schedstat_before{"sis_recent_miss"} += $sis_recent_miss;
				$schedstat_before{"sis_core_search"} += $sis_core_search;
				$schedstat_before{"mmtests_sis_core_hit"} += $sis_core_hit;
				$schedstat_before{"sis_core_miss"} += $sis_core_miss;
			}

			if ($reading_after) {
				$schedstat_after{"ttwu_count"}  += $ttwu_count;
				$schedstat_after{"ttwu_local"}  += $ttwu_local;
				$schedstat_after{"sis_search"}  += $sis_search;
				$schedstat_after{"sis_domain_search"}  += $sis_domain_search;
				$schedstat_after{"sis_scanned"} += $sis_scanned;
				$schedstat_after{"sis_failed"}  += $sis_failed;
				$schedstat_after{"sis_recent_hit"} += $sis_recent_hit;
				$schedstat_after{"sis_recent_miss"} += $sis_recent_miss;
				$schedstat_after{"sis_core_search"} += $sis_core_search;
				$schedstat_after{"mmtests_sis_core_hit"} += $sis_core_hit;
				$schedstat_after{"sis_core_miss"} += $sis_core_miss;
			}
		}
	}
	close ($input);

	foreach my $key ("sis_search", "sis_domain_search", "sis_scanned", "sis_failed", "ttwu_count", "ttwu_local", "sis_recent_hit", "sis_recent_miss", "sis_core_search", "mmtests_sis_core_hit", "sis_core_miss") {
		$schedstat{$key} = $schedstat_after{$key} - $schedstat_before{$key};
	}

	my $fast_search = $schedstat{"sis_search"} - $schedstat{"sis_domain_search"};
	my $domain_scanned = $schedstat{"sis_scanned"} - $fast_search;
	my $recent_total = $schedstat{"sis_recent_hit"} + $schedstat{"sis_recent_miss"};
	my $core_total = $schedstat{"sis_recent_hit"} + $schedstat{"sis_core_miss"};

	# mmtests_sis_recent_success
	if (!$recent_total) {
		$schedstat{"mmtests_sis_recent_success"} = 0;
		$schedstat{"mmtests_sis_recent_attempts"} = 0;
	} else {
		$schedstat{"mmtests_sis_recent_success"} = $schedstat{"sis_recent_hit"} * 100 / $recent_total;
		$schedstat{"mmtests_sis_recent_attempts"} = $recent_total;
	}

	# mmtests_sis_efficiency
	if (!$schedstat{"sis_scanned"}) {
		$schedstat{"mmtests_sis_efficiency"} = 100;
	} else {
		$schedstat{"mmtests_sis_efficiency"} = $schedstat{"sis_search"} * 100 / $schedstat{"sis_scanned"};
	}

	# mmtests_sis_domain_efficiency
	if (!$schedstat{"sis_scanned"}) {
		$schedstat{"mmtests_sis_domain_efficiency"} = 100;
	} else {
		$schedstat{"mmtests_sis_domain_efficiency"} = $schedstat{"sis_domain_search"} * 100 / $domain_scanned;
	}

	# mmtests_sis_core_efficiency
	if (!$core_total) {
		$schedstat{"mmtests_sis_core_efficiency"} = 100;
	} else {
		$schedstat{"mmtests_sis_core_efficiency"} = $schedstat{"mmtests_sis_core_hit"} * 100 / $core_total;
	}

	# mmtests_sis_fast_success
	if (!$schedstat{"sis_search"}) {
		$schedstat{"mmtests_sis_fast_success"} = 100;
	} else {
		my $fast_search = $schedstat{"sis_search"} - $schedstat{"sis_domain_search"};

		$schedstat{"mmtests_sis_fast_success"} =  $fast_search * 100 / $schedstat{"sis_search"};
	}

	if (!$schedstat{"sis_search"}) {
		$schedstat{"mmtests_sis_success"} = 100;
	} else {
		my $sis_success = $schedstat{"sis_search"} - $schedstat{"sis_failed"};
		$schedstat{"mmtests_sis_success"} = $sis_success * 100 / $schedstat{"sis_search"};
	}

	$schedstat{"mmtests_sis_domain_scanned"} = $domain_scanned;

	foreach my $key (@_fieldOrder) {
		my $keyName;
		my $keyName = $_fieldNameMap{$key};
		$self->addData($keyName, 0, $schedstat{$key} );
	}
}
