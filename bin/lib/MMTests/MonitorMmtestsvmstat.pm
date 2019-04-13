# MonitorMmtestsvmstat.pm
package MMTests::MonitorMmtestsvmstat;
use MMTests::Monitor;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName	=> "Mmtestsvmstat",
		_DataType	=> MMTests::Monitor::MONITOR_VMSTAT,
		_ResultData	=> [],
		_MultiopMonitor => 1,
		_SingleSample	=> 1,
	};
	bless $self, $class;
	return $self;
}

my %_fieldNameMap = (
	"mmtests_minor_faults"		=> "Minor Faults",
	"pgmajfault"			=> "Major Faults",
	"pgpgin"			=> "Sector Reads",
	"pgpgout"			=> "Sector Writes",
	"pswpin"			=> "Swap Ins",
	"pswpout"			=> "Swap Outs",
	"allocstall"			=> "Allocation stalls",
	"fragment_stall"		=> "Fragmentation stalls",
	"pgalloc_dma"			=> "DMA allocs",
	"pgalloc_dma32"			=> "DMA32 allocs",
	"pgalloc_normal"		=> "Normal allocs",
	"pgalloc_movable"		=> "Movable allocs",
	"mmtests_direct_scan"		=> "Direct pages scanned",
	"mmtests_kswapd_scan"		=> "Kswapd pages scanned",
	"mmtests_kswapd_steal"		=> "Kswapd pages reclaimed",
	"mmtests_direct_steal"		=> "Direct pages reclaimed",
	"mmtests_kswapd_efficiency"	=> "Kswapd efficiency %",
	"mmtests_kswapd_velocity"	=> "Kswapd velocity",
	"mmtests_direct_efficiency"	=> "Direct efficiency %",
	"mmtests_direct_velocity"	=> "Direct velocity",
	"mmtests_direct_percentage"	=> "Percentage direct scans",
	"mmtests_highmem_velocity"	=> "Zone highmem velocity",
	"mmtests_normal_velocity"	=> "Zone normal velocity",
	"mmtests_dma32_velocity"	=> "Zone dma32 velocity",
	"mmtests_dma_velocity"		=> "Zone dma velocity",
	"nr_vmscan_write"		=> "Page writes by reclaim",
	"mmtests_vmscan_write_file"	=> "Page writes file",
	"mmtests_vmscan_write_anon"	=> "Page writes anon",
	"nr_vmscan_immediate_reclaim"	=> "Page reclaim immediate",
	"pgrescued"			=> "Page rescued immediate",
	"slabs_scanned"			=> "Slabs scanned",
	"pginodesteal"			=> "Direct inode steals",
	"kswapd_inodesteal"		=> "Kswapd inode steals",
	"kswapd_skip_congestion_wait"	=> "Kswapd skipped wait",
	"thp_fault_alloc"		=> "THP fault alloc",
	"thp_collapse_alloc"		=> "THP collapse alloc",
	"thp_split_page"		=> "THP split",
	"thp_split_page_failed"		=> "THP split failed",
	"thp_fault_fallback"		=> "THP fault fallback",
	"thp_collapse_alloc_failed"	=> "THP collapse fail",
	"compact_stall"			=> "Compaction stalls",
	"compact_success"		=> "Compaction success",
	"mmtests_compact_efficiency"	=> "Compaction efficiency",
	"pgmigrate_success"		=> "Page migrate success",
	"pgmigrate_fail"		=> "Page migrate failure",
	"compact_isolated"		=> "Compaction pages isolated",
	"compact_migrate_scanned"	=> "Compaction migrate scanned",
	"compact_free_scanned"		=> "Compaction free scanned",
	"compact_fail"			=> "Compaction failures",
	"compact_pages_moved"		=> "Compaction pages moved",
	"compact_pagemigrate_failed"	=> "Compaction move failure",
	"mmtests_cscan_efficiency"	=> "Compact scan efficiency",
	"mmtests_compaction_cost"	=> "Compaction cost",
	"numa_hit"			=> "NUMA alloc hit",
	"numa_miss"			=> "NUMA alloc miss",
	"numa_interleave"		=> "NUMA interleave hit",
	"numa_local"			=> "NUMA alloc local",
	"numa_pte_updates"		=> "NUMA base PTE updates",
	"numa_huge_pte_updates"		=> "NUMA huge PMD updates",
	"mmtests_numa_pte_updates"	=> "NUMA page range updates",
	"numa_hint_faults"		=> "NUMA hint faults",
	"numa_hint_faults_local"	=> "NUMA hint local faults %",
	"mmtests_hint_local"		=> "NUMA hint local percent",
	"numa_pages_migrated"		=> "NUMA pages migrated",
	"mmtests_autonuma_cost"		=> "AutoNUMA cost",
	"compact_daemon_wake",		=> "Kcompactd wake",
	"compact_daemon_migrate_scanned"=> "Kcompactd migrate scanned",
	"compact_daemon_free_scanned"	=> "Kcompactd free scanned",
);

my %_renamed_fields = (
	"compact_pages_moved"		=> "pgmigrate_success",
	"compact_pagemigrate_failed"	=> "pgmigrate_failed",
	"thp_split"  			=> "thp_split_page",
	"thp_failed" 			=> "thp_split_page_failed",
	"allocstall_dma"		=> "allocstall",
	"allocstall_dma32"		=> "allocstall",
	"allocstall_normal"		=> "allocstall",
	"allocstall_movable"		=> "allocstall",
	"allocstall_highmem"		=> "allocstall",
);

my @_fieldOrder = (
	"mmtests_minor_faults",
	"pgmajfault",
	"pswpin",
	"pswpout",
	"allocstall",
	"fragment_stall",
	"pgalloc_dma",
	"pgalloc_dma32",
	"pgalloc_normal",
	"pgalloc_movable",
	"mmtests_direct_scan",
	"mmtests_kswapd_scan",
	"mmtests_kswapd_steal",
	"mmtests_direct_steal",
	"mmtests_kswapd_efficiency",
	"mmtests_kswapd_velocity",
	"mmtests_direct_efficiency",
	"mmtests_direct_velocity",
	"mmtests_direct_percentage",
	# "mmtests_highmem_velocity",
	# "mmtests_normal_velocity",
	# "mmtests_dma32_velocity",
	# "mmtests_dma_velocity",
	"nr_vmscan_write",
	"mmtests_vmscan_write_file",
	"mmtests_vmscan_write_anon",
	"nr_vmscan_immediate_reclaim",
	"pgpgin",
	"pgpgout",
	"pgrescued",
	"slabs_scanned",
	"pginodesteal",
	"kswapd_inodesteal",
	"kswapd_skip_congestion_wait",
	"thp_fault_alloc",
	"thp_fault_fallback",
	"thp_collapse_alloc",
	"thp_collapse_alloc_failed",
	"thp_split_page",
	"thp_split_page_failed",
	"compact_stall",
	"compact_success",
	"compact_fail",
	"mmtests_compact_efficiency",
	"pgmigrate_success",
	"pgmigrate_fail",
	"compact_isolated",
	"compact_migrate_scanned",
	"compact_free_scanned",
	"mmtests_cscan_efficiency",
	"mmtests_compaction_cost",
	"compact_daemon_wake",
	"compact_daemon_migrate_scanned",
	"compact_daemon_free_scanned",
	"numa_hit",
	"numa_miss",
	"numa_interleave",
	"numa_local",
	"numa_pte_updates",
	"numa_huge_pte_updates",
	"mmtests_numa_pte_updates",
	"numa_hint_faults",
	"numa_hint_faults_local",
	"mmtests_hint_local",
	"numa_pages_migrated",
	"mmtests_autonuma_cost",
);

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my (%vmstat_before, %vmstat_after, %vmstat);
	my ($reading_test, $reading_before, $reading_after);
	my $elapsed_time = 1;

	my $file = "$reportDir/tests-timestamp-$testName";

	foreach my $key (keys %_renamed_fields) {
		$vmstat_before{$_renamed_fields{$key}} = 0;
		$vmstat_after{$_renamed_fields{$key}} = 0;
	}

	foreach my $key (keys @_fieldOrder) {
		$vmstat_before{$key} = 0;
		$vmstat_after{$key} = 0;
	}

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		if ($_ =~ /^test begin \:\: $testBenchmark/) {
			$reading_test = 1;
			next;
		}

		if ($_ =~ /^time :: $testBenchmark/) {
			my @elements = split(/\s/, $_);
			$elapsed_time = $elements[7];
		}

		if ($reading_test) {
			if ($_ =~ /^file start :: \/proc\/vmstat/) {
				$reading_before = 1;
				next;
			}

			if ($_ =~ /^file start :: \/proc\/zoneinfo/) {
				$reading_before = 0;
				next;
			}

			if ($_ =~ /^file end :: \/proc\/vmstat/) {
				$reading_after = 1;
				next;
			}

			if ($_ =~ /^file end :: \/proc\/zoneinfo/) {
				$reading_after = 0;
				next;
			}

			if ($_ =~ /^test end :: $testBenchmark/) {
				$reading_test = 0;
				next;
			}

			my ($key, $value) = split(/\s/, $_);
			if (defined $_renamed_fields{$key}) {
				$key = $_renamed_fields{$key};
			}
			if ($reading_before) {
				$vmstat_before{$key} = $value;
			} elsif ($reading_after) {
				$vmstat_after{$key} = $value;
			}
		}
	}
	close INPUT;

	# kswapd steal
	foreach my $key ("kswapd_steal", "pgsteal_kswapd_dma", "pgsteal_kswapd_dma32",
			 "pgsteal_kswapd_normal", "pgsteal_kswapd_high",
			 "pgsteal_kswapd_movable", "pgsteal_kswapd") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
		$vmstat{"mmtests_kswapd_steal"} += $value;
	}

	# direct steal
	my $direct_steals;
	foreach my $key ("pgsteal_dma", "pgsteal_dma32", "pgsteal_normal",
			 "pgsteal_movable", "pgsteal_high", "pgsteal_direct_dma",
			 "pgsteal_direct_dma32", "pgsteal_direct_normal",
			 "pgsteal_direct_movable", "pgsteal_direct_high",
			 "pgsteal_direct") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
		$vmstat{"mmtests_direct_steal"} += $value;
	}
	if (defined $vmstat_before{"kswapd_steal"}) {
		$vmstat{"mmtests_direct_steal"} -= $vmstat{"mmtests_kswapd_steal"};
	}

	# kswap scan
	foreach my $key ("pgscan_kswapd_dma", "pgscan_kswapd_dma32",
			 "pgscan_kswapd_normal", "pgscan_kswapd_movable",
			 "pgscan_kswapd_high", "pgscan_kswapd") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
		$vmstat{"mmtests_kswapd_scan"} += $value;


		# Record the zone being scanned
		my @elements = split(/_/, $key);
		my $zone = $elements[-1];
		if ($zone eq "kswapd") {
			$zone = "normal";
		}
		$vmstat{"mmtests_${zone}_scanned"} += $value;
	}
	$vmstat{"mmtests_kswapd_velocity"} = $vmstat{"mmtests_kswapd_scan"} / $elapsed_time;

	# direct scan
	foreach my $key ("pgscan_direct_dma", "pgscan_direct_dma32",
			  "pgscan_direct_normal", "pgscan_direct_movable",
			  "pgscan_direct_high", "pgscan_direct") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
		$vmstat{"mmtests_direct_scan"} += $value;

		# Record the zone being scanned
		my @elements = split(/_/, $key);
		my $zone = $elements[-1];
		if ($zone eq "direct") {
			$zone = "normal";
		}
		$vmstat{"mmtests_${zone}_scanned"} += $value;
	}
	$vmstat{"mmtests_direct_velocity"} = $vmstat{"mmtests_direct_scan"} / $elapsed_time;

	if (defined $vmstat{"mmtests_movable_scanned"}) {
		$vmstat{"mmtests_movable_velocity"} = $vmstat{"mmtests_movable_scanned"} / $elapsed_time;
	}
	if (defined $vmstat{"mmtests_highmem_scanned"}) {
		$vmstat{"mmtests_highmem_velocity"} = $vmstat{"mmtests_highmem_scanned"} / $elapsed_time;
	}
	$vmstat{"mmtests_normal_velocity"}  = $vmstat{"mmtests_normal_scanned"}  / $elapsed_time;
	$vmstat{"mmtests_dma32_velocity"}   = $vmstat{"mmtests_dma32_scanned"}   / $elapsed_time;
	$vmstat{"mmtests_dma_velocity"}     = $vmstat{"mmtests_dma_scanned"}     / $elapsed_time;

	# kswapd efficiency
	if ($vmstat{"mmtests_direct_scan"}) {
		$vmstat{"mmtests_direct_efficiency"} = $vmstat{"mmtests_direct_steal"} * 100 / $vmstat{"mmtests_direct_scan"};
	} else {
		$vmstat{"mmtests_direct_efficiency"} = 100;
	}
	if ($vmstat{"mmtests_kswapd_scan"}) {
		$vmstat{"mmtests_kswapd_efficiency"} = $vmstat{"mmtests_kswapd_steal"} * 100 / $vmstat{"mmtests_kswapd_scan"};
	} else {
		$vmstat{"mmtests_kswapd_efficiency"} = 100;
	}

	my $total_scanned = $vmstat{"mmtests_kswapd_scan"} + $vmstat{"mmtests_direct_scan"};
	if ($total_scanned) {
		$vmstat{"mmtests_direct_percentage"} = $vmstat{"mmtests_direct_scan"} * 100 / $total_scanned;
	} else {
		$vmstat{"mmtests_direct_percentage"} = 0;
	}

	# Flat values
	foreach my $key ("pgpgin", "pgpgout", "pswpin", "pswpout",
			 "pgfault", "pgmajfault", "allocstall", "fragment_stall",
			 "pgalloc_dma", "pgalloc_dma32", "pgalloc_normal", "pgalloc_movable",
			 "kswapd_inodesteal", "pginodesteal", "slabs_scanned",
			 "compact_pages_moved", "compact_pagemigrate_failed",
			 "compact_fail", "compact_success", "compact_stall",
			 "compact_daemon_wake", "compact_daemon_migrate_scanned",
			 "compact_daemon_free_scanned",
			 "nr_vmscan_write", "kswapd_skip_congestion_wait",
			 "nr_vmscan_immediate_reclaim", "pgrescued",
			 "pgmigrate_success", "pgmigrate_fail",
			 "compact_blocks_moved",
			 "compact_isolated",
			 "compact_migrate_scanned", "compact_free_scanned",
			 "numa_hit", "numa_miss", "numa_interleave", "numa_local",
			 "numa_pte_updates", "numa_huge_pte_updates",
			 "numa_hint_faults",
			 "numa_hint_faults_local", "numa_pages_migrated",
			 "thp_fault_alloc", "thp_collapse_alloc",
			 "thp_split_page", "thp_split_page_failed",
			 "thp_fault_fallback",
			 "thp_collapse_alloc_failed") {
		if (!defined($vmstat_after{$key})) {
			$vmstat{$key} = 0;
		} else {
			my $value = $vmstat_after{$key} - $vmstat_before{$key};
			$vmstat{$key} = $value;
		}
	}
	$vmstat{"mmtests_vmscan_write_file"} = $vmstat{"nr_vmscan_write"} - $vmstat{"pswpout"};
	$vmstat{"mmtests_vmscan_write_anon"} = $vmstat{"pswpout"};
	$vmstat{"mmtests_minor_faults"} = $vmstat{"pgfault"} - $vmstat{"pgmajfault"};
	if ($vmstat{"numa_hint_faults"}) {
		$vmstat{"mmtests_hint_local"} = $vmstat{"numa_hint_faults_local"} * 100 / $vmstat{"numa_hint_faults"};
	} else {
		$vmstat{"mmtests_hint_local"} = 100;
	}
	$vmstat{"mmtests_numa_pte_updates"} =  $vmstat{"numa_pte_updates"};
	if (defined $vmstat{"numa_huge_pte_updates"}) {
		$vmstat{"mmtests_numa_pte_updates"} += $vmstat{"numa_huge_pte_updates"} * 512;
	}

	# Compaction cost model
	my $Ca  = 56 / 8;	# Values for x86-64
	my $Cpagerw = ($Ca + (4096 / 8));
	my $Cmc = $Cpagerw * 2;
	my $Cmf = $Ca * 2;
	my $Ci  = $Ca + 12;	# 4 for list operations, 8 for locks
	my $Csm = $Ca;
	my $Csf = $Ca;
	$vmstat{"mmtests_compaction_cost"} = -1;
	if (defined $vmstat_before{"compact_migrate_scanned"} ) {
		$vmstat{"mmtests_compaction_cost"} =
			$Csm * $vmstat{"compact_migrate_scanned"} +
			$Csf * $vmstat{"compact_migrate_free"} +
			$Ci  * $vmstat{"compact_isolated"} +
			$Cmc * $vmstat{"pgmigrate_success"} +
			$Cmf * $vmstat{"pgmigrate_fail"};
	}
	if (defined $vmstat_before{"compact_blocks_moved"}) {
		$vmstat{"mmtests_compaction_cost"} =
			$Csm * $vmstat{"compact_blocks_moved"} * 16384 +
			$Cmc * $vmstat{"compact_pages_moved"} +
			$Cmf * $vmstat{"compact_pagemigrate_failed"};
	}
	$vmstat{"mmtests_compaction_cost"} /= 1000000;

	# AutoNUMA cost model
	my $Cpte = $Ca;
	my $Cupdate = (2 * $Cpte) + (2 * 8);
	my $Cnumahint = 5000;
	$Cmc = $Cpagerw + $Cpagerw * 1.5;

	$vmstat{"mmtests_autonuma_cost"} =
			$Cpte * $vmstat{"numa_pte_updates"} +
			$Cnumahint * $vmstat{"numa_hint_faults"} +
			$Ci * $vmstat{"numa_pages_migrated"};
			$Cpagerw * $vmstat{"numa_pages_migrated"};
	$vmstat{"mmtests_autonuma_cost"} /= 1000000;

	# Compaction efficiency
	if ($vmstat{"compact_stall"}) {
		$vmstat{"mmtests_compact_efficiency"} = $vmstat{"compact_success"} * 100 / $vmstat{"compact_stall"};
	}

	# Compact scan efficiency
	if ($vmstat{"compact_migrate_scanned"}) {
		$vmstat{"mmtests_cscan_efficiency"} = $vmstat{"compact_migrate_scanned"} * 100 / $vmstat{"compact_free_scanned"};
	}

	my $fieldLength = 0;
key:	foreach my $key (@_fieldOrder) {
		my $keyName = $key;
		my $suppress = 0;

		my $keyName = $_fieldNameMap{$key};
		$self->addData($keyName, 0, $vmstat{$key} );

		# Work out the length of the largest field
		my $length = length($keyName);
		if ($length > $fieldLength) {
			$fieldLength = $length;
		}
	}
	$fieldLength++;

	$self->{_FieldLength} = 15;
	$self->{_FieldHeaders} = [ "Op", "Value" ];
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "", "%12.2f" ];
}

1;
