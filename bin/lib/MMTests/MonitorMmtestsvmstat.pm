# MonitorMmtestsvmstat.pm
package MMTests::MonitorMmtestsvmstat;
use MMTests::Monitor;
use VMR::Report;
our @ISA = qw(MMTests::Monitor); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "Mmtestsvmstat",
		_DataType      => MMTests::Monitor::MONITOR_VMSTAT,
		_RowOrientated => 1,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

my $new_compaction_stats = 0;
my $autonuma_enabled = 1;

my %_fieldNameMap = (
	"pgpgin"			=> "Page Ins",
	"pgpgout"			=> "Page Outs",
	"pswpin"			=> "Swap Ins",
	"pswpout"			=> "Swap Outs",
	"mmtests_direct_scan"		=> "Direct pages scanned",
	"mmtests_kswapd_scan"		=> "Kswapd pages scanned",
	"mmtests_kswapd_steal"		=> "Kswapd pages reclaimed",
	"mmtests_direct_steal"		=> "Direct pages reclaimed",
	"mmtests_kswapd_efficiency"	=> "Kswapd efficiency",
	"mmtests_kswapd_velocity"	=> "Kswapd velocity",
	"mmtests_direct_efficiency"	=> "Direct efficiency",
	"mmtests_direct_velocity"	=> "Direct velocity",
	"mmtests_direct_percentage"	=> "Percentage direct scans",
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
	"thp_split"			=> "THP splits",
	"thp_fault_fallback"		=> "THP fault fallback",
	"thp_collapse_alloc_failed"	=> "THP collapse fail",
	"compact_stall"			=> "Compaction stalls",
	"compact_success"		=> "Compaction success",
	"pgmigrate_success"		=> "Page migrate success",
	"pgmigrate_failure"		=> "Page migrate failure",
	"compact_isolated"		=> "Compaction pages isolated",
	"compact_migrate_scanned"	=> "Compaction migrate scanned",
	"compact_free_scanned"		=> "Compaction free scanned",
	"compact_fail"			=> "Compaction failures",
	"compact_pages_moved"		=> "Compaction pages moved",
	"compact_pagemigrate_failed"	=> "Compaction move failure",
	"mmtests_compaction_cost"	=> "Compaction cost",
	"numa_pte_updates"		=> "NUMA PTE updates",
	"numa_hint_faults"		=> "NUMA hint faults",
	"numa_hint_faults_local"	=> "NUMA hint local faults",
	"numa_pages_migrated"		=> "NUMA pages migrated",
	"mmtests_autonuma_cost"		=> "AutoNUMA cost",
);

my @_old_migrate_stats = (
	"compact_pages_moved",
	"compact_pagemigrate_failed",
);

my @_new_migrate_stats = (
	"compact_migrate_scanned",
	"compact_free_scanned",
	"compact_isolated",
	"pgmigrate_success",
	"pgmigrate_failure",
);

my @_autonuma_stats = (
	"numa_pte_updates",
	"numa_hint_faults",
	"numa_hint_faults_local",
	"numa_pages_migrated",
	"mmtests_autonuma_cost",
);

my @_fieldOrder = (
	"blank",
        "pgpgin",
        "pgpgout",
        "pswpin",
        "pswpout",
        "mmtests_direct_scan",
        "mmtests_kswapd_scan",
        "mmtests_kswapd_steal",
        "mmtests_direct_steal",
        "mmtests_kswapd_efficiency",
        "mmtests_kswapd_velocity",
        "mmtests_direct_efficiency",
        "mmtests_direct_velocity",
        "mmtests_direct_percentage",
        "nr_vmscan_write",
        "mmtests_vmscan_write_file",
        "mmtests_vmscan_write_anon",
        "nr_vmscan_immediate_reclaim",
        "pgrescued",
        "slabs_scanned",
        "pginodesteal",
        "kswapd_inodesteal",
        "kswapd_skip_congestion_wait",
        "thp_fault_alloc",
        "thp_collapse_alloc",
        "thp_split",
        "thp_fault_fallback",
        "thp_collapse_alloc_failed",
        "compact_stall",
        "compact_success",
        "compact_fail",
        "pgmigrate_success",
        "pgmigrate_failure",
        "compact_pages_moved",
        "compact_pagemigrate_failed",
        "compact_isolated",
        "compact_migrate_scanned",
        "compact_free_scanned",
	"mmtests_compaction_cost",
	"numa_pte_updates",
	"numa_hint_faults",
	"numa_hint_faults_local",
	"numa_pages_migrated",
	"mmtests_autonuma_cost",
);

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my (%vmstat_before, %vmstat_after, %vmstat);
	my ($reading_test, $reading_before, $reading_after);
	my $elapsed_time;

	my $file = "$reportDir/tests-timestamp-$testName";

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
			if ($reading_before) {
				$vmstat_before{$key} = $value;
			} elsif ($reading_after) {
				$vmstat_after{$key} = $value;
			}
			if ($key eq "pgmigrate_success") {
				$new_compaction_stats = 1;
			}
			if ($key eq "numa_hint_faults") {
				$autonuma_enabled = 1;
			}
		}
	}
	close INPUT;

	# kswapd steal
	foreach my $key ("kswapd_steal", "pgsteal_kswapd_dma", "pgsteal_kswapd_dma32",
			 "pgsteal_kswapd_normal", "pgsteal_kswapd_high",
			 "pgsteal_kswapd_movable") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
		$vmstat{"mmtests_kswapd_steal"} += $value;
	}

	# direct steal
	my $direct_steals;
	foreach my $key ("pgsteal_dma", "pgsteal_dma32", "pgsteal_normal",
			 "pgsteal_movable", "pgsteal_high", "pgsteal_direct_dma",
			 "pgsteal_direct_dma32", "pgsteal_direct_normal",
			 "pgsteal_direct_movable", "pgsteal_direct_high") {
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
			 "pgscan_kswapd_high") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
		$vmstat{"mmtests_kswapd_scan"} += $value;
	}
	$vmstat{"mmtests_kswapd_velocity"} = $vmstat{"mmtests_kswapd_scan"} / $elapsed_time;

	# direct scan
	foreach my $key ("pgscan_direct_dma", "pgscan_direct_dma32", 
			  "pgscan_direct_normal", "pgscan_direct_movable",
			  "pgscan_direct_high") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
		$vmstat{"mmtests_direct_scan"} += $value;
	}
	$vmstat{"mmtests_direct_velocity"} = $vmstat{"mmtests_direct_scan"} / $elapsed_time;

	# efficiency
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
			 "kswapd_inodesteal", "pginodesteal", "slabs_scanned",
			 "compact_pages_moved", "compact_pagemigrate_failed",
			 "compact_fail", "compact_success", "compact_stall",
			 "nr_vmscan_write", "kswapd_skip_congestion_wait",
			 "nr_vmscan_immediate_reclaim", "pgrescued",
        		 "pgmigrate_success", "pgmigrate_failure",
			 "compact_blocks_moved",
        		 "compact_isolated", "compact_migrate_scanned",
        		 "compact_free_scanned",
        		 "numa_pte_updates", "numa_hint_faults",
        		 "numa_hint_faults_local", "numa_pages_migrated",
			 "thp_fault_alloc", "thp_collapse_alloc",
			 "thp_split", "thp_fault_fallback",
			 "thp_collapse_alloc_failed") {
		my $value = $vmstat_after{$key} - $vmstat_before{$key};
		$vmstat{$key} = $value;
	}
	$vmstat{"mmtests_vmscan_write_file"} = $vmstat{"nr_vmscan_write"} - $vmstat{"pswpout"};
	$vmstat{"mmtests_vmscan_write_anon"} = $vmstat{"pswpout"};

	# Compaction cost model
	my $Ca  = 56 / 8;	# Values for x86-64
	my $Cpagerw = ($Ca + (4096 / 8));
	my $Cmc = $Cpagerw * 2;
	my $Cmf = $Ca * 2;
	my $Ci  = $Ca + 12;	# 4 for list operations, 8 for locks
	my $Csm = $Ca;
	my $Csf = $Ca;
	if ($new_compaction_stats ) {
		$vmstat{"mmtests_compaction_cost"} =
			$Csm * $vmstat{"compact_migrate_scanned"} +
			$Csf * $vmstat{"compact_migrate_free"} +
			$Ci  * $vmstat{"compact_isolated"} +
			$Cmc * $vmstat{"pgmigrate_success"} +
			$Cmf * $vmstat{"pgmigrate_fail"};
	} else {
		$vmstat{"mmtests_compaction_cost"} =
			$Csm * $vmstat{"compact_blocks_moved"} * 16384 +
			$Cmc * $vmstat{"compact_pages_moved"} +
			$Cmf * $vmstat{"compact_pagemigrate_failed"};
	}
	$vmstat{"mmtests_compaction_cost"} /= 1000000;

	# AutoNUMA cost model
	if ($autonuma_enabled) {
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
	}



	# Pick order to display keys in
	my @keys;
	if ($rowOrientated) {
		@keys = @_fieldOrder;
	} else {
		@keys = sort keys %vmstat;
	}

	my $fieldLength = 0;
	my (@headers, @fields, @format);
	my $count = 0;
key:	foreach my $key (@keys) {
		my $keyName = $key;
		my $suppress = 0;

		# Some stats for migration may have changed
		if ($new_compaction_stats) {
			foreach my $compareKey (@_old_migrate_stats) {
				if ($compareKey eq $key) {
					next key;
				}
			}
		} else {
			foreach my $compareKey (@_new_migrate_stats) {
				if ($compareKey eq $key) {
					next key;
				}
			}
		}

		# AutoNUMA may not be available
		if (!$autonuma_enabled) {
			foreach my $compareKey (@_autonuma_stats) {
				if ($compareKey eq $key) {
					next key;
				}
			}
		}

		if ($rowOrientated && $_fieldNameMap{$key}) {
			$keyName = $_fieldNameMap{$key};
		}
		push @headers, $keyName;
		push @fields, $vmstat{$key};

		# Work out the length of the largest field
		my $length = length($key);
		if ($length > $fieldLength) {
			$fieldLength = $length;
		}
		$count++;
	}
	$fieldLength++;

	# Override the field length if requested. In practice this happens when the
	# columns of one table are being turned into the rows of the other.
	if ($rowOrientated) {
		$fieldLength = 12;
	}

	foreach my $key (@keys) {
		if ($key eq "mmtests_kswapd_efficiency" ||
		    $key eq "mmtests_direct_efficiency" ||
		    $key eq "mmtests_direct_percentage") {
			my $length = $fieldLength - 1;
			push @format, "%${length}d%%";
		} elsif ($key eq "mmtests_kswapd_velocity" ||
			 $key eq "mmtests_direct_velocity") {
			push @format, "%${fieldLength}.3f";
		} else {
			push @format, "%${fieldLength}d";
		}
	}
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = \@headers;
	$self->{_RowFieldFormat} = \@format;
	push @{$self->{_ResultData}}, \@fields;
}

1;
