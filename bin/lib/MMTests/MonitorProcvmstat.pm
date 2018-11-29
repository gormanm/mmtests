# MonitorProcvmstat.pm
package MMTests::MonitorProcvmstat;
use MMTests::Monitor;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorProcvmstat",
		_DataType      => MMTests::Monitor::MONITOR_PROCVMSTAT,
		_RowOrientated => 1,
		_ResultData    => []
	};
	bless $self, $class;
	return $self;
}

my $new_compaction_stats = 0;
my $autonuma_enabled = 0;

my %_fieldCounters = (
	"nr_active_anon"	=> 1,
	"nr_active_file"	=> 1,
	"nr_anon_pages"		=> 1,
	"nr_anon_transparent_hugepages"	=> 1,
	"nr_dirty"		=> 1,
	"nr_file_pages"		=> 1,
	"nr_free_cma"		=> 1,
	"nr_free_pages"		=> 1,
	"nr_inactive_anon"	=> 1,
	"nr_inactive_file"	=> 1,
	"nr_isolated_anon"	=> 1,
	"nr_isolated_file"	=> 1,
	"nr_kernel_stack"	=> 1,
	"nr_mapped"		=> 1,
	"nr_mlock"		=> 1,
	"nr_page_table_pages"	=> 1,
	"nr_shmem"		=> 1,
	"nr_slab_reclaimable"	=> 1,
	"nr_slab_unreclaimable"	=> 1,
	"nr_unevictable"	=> 1,
	"nr_unstable"		=> 1,
	"nr_writeback"		=> 1,
	"nr_writeback_temp"	=> 1,
	"nr_dirty_background_threshold" => 1
);

my %_fieldNameMap = (
	"pgpgtotal"			=> "Total Sectors IO",
	"pgpgin"			=> "Sector Reads",
	"pgpgout"			=> "Sector Writes",
	"mmtests_minor_faults"		=> "Minor Faults",
	"pgmajfault"			=> "Major Faults",
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
	"mmtests_hint_faults_remote"	=> "NUMA hint remote faults",
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
	"numa_hint_faults_remote",
	"numa_hint_faults_local",
	"numa_pages_migrated",
	"mmtests_autonuma_cost",
);

my @_fieldOrder = (
	"blank",
	"mmtests_minor_faults",
	"pgmajfault",
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
        "pgpgtotal",
        "pgpgin",
        "pgpgout",
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
	"mmtests_hint_faults_remote",
	"numa_hint_faults_local",
	"numa_pages_migrated",
	"mmtests_autonuma_cost",
);

sub printDataType() {
	my ($self) = @_;
	my $heading = $self->{_Heading};
	my $niceHeading = $_fieldNameMap{$heading};
	if ($niceHeading eq "") {
		$niceHeading = $heading;
	}

	print "Vmstat,Time,$niceHeading\n";
}

sub parseVMStat($)
{
	my ($self, $vmstatOutput, $subHeading) = @_;
	my $current_value = 0;
	my $window = $self->{_Window};

	my @mmtests_direct_scan = ("pgscan_direct_dma", "pgscan_direct_dma32",
                          "pgscan_direct_normal", "pgscan_direct_movable",
                          "pgscan_direct_high");
	my @mmtests_direct_nodelru_scan = ("pgscan_direct");
	my @mmtests_direct_steal = ("pgsteal_dma", "pgsteal_dma32",
			  "pgsteal_normal", "pgsteal_movable", "pgsteal_high",
			  "pgsteal_direct_dma", "pgsteal_direct_dma32",
			  "pgsteal_direct_normal", "pgsteal_direct_movable",
			  "pgsteal_direct_high", "pgsteal_direct");
	my @mmtests_kswapd_scan = ("pgscan_kswapd_dma", "pgscan_kswapd_dma32",
			 "pgscan_kswapd_normal", "pgscan_kswapd_movable",
			 "pgscan_kswapd_high") ;
	my @mmtests_kswapd_nodelru_scan = ("pgscan_kswapd");
        my @mmtests_kswapd_steal = ("kswapd_steal", "pgsteal_kswapd_dma", "pgsteal_kswapd_dma32",
			  "pgsteal_kswapd_normal", "pgsteal_kswapd_high",
			  "pgsteal_kswapd_movable", "pgsteal_kswapd");
        my @mmtests_slab = ("nr_slab_reclaimable", "nr_slab_unreclaimable");

	my $current_scan = 0;
	my $current_steal = 0;
	my $nr_anon = 0;
	my $nr_thp_anon = 0;

	foreach my $line (split(/\n/, $_[1])) {
		my ($stat, $value) = split(/\s/, $line);
		if ($subHeading eq "mmtests_direct_scan" ) {
			foreach my $key (@mmtests_direct_scan) {
				if ($stat eq $key) {
					$current_value += $value;
				}
			}
			foreach my $key (@mmtests_direct_nodelru_scan) {
				if ($stat eq $key) {
					$current_value += $value;
				}
			}
		} elsif ($subHeading eq "mmtests_total_anon") {
			if ($stat eq "nr_anon_pages") {
				$nr_anon = $value;
			}
			if ($stat eq "nr_anon_transparent_hugepages") {
				$nr_thp_anon = $value;
			}
		} elsif ($subHeading eq "mmtests_direct_steal" ) {
			foreach my $key (@mmtests_direct_steal) {
				if ($stat eq $key) {
					if ($key eq "kswapd_steal") {
						$current_value -= $value;
					} else {
						$current_value += $value;
					}
				}
			}
		} elsif ($subHeading eq "mmtests_direct_efficiency" ) {
			foreach my $key (@mmtests_direct_scan) {
				if ($stat eq $key) {
					$current_scan += $value;
				}
			}
			foreach my $key (@mmtests_direct_steal) {
				if ($stat eq $key) {
					if ($key eq "kswapd_steal") {
						$current_steal -= $value;
					} else {
						$current_steal += $value;
					}
				}
			}
		} elsif ($subHeading eq "mmtests_kswapd_scan") {
			foreach my $key (@mmtests_kswapd_scan) {
				if ($stat eq $key) {
					$current_value += $value;
				}
			}
			foreach my $key (@mmtests_kswapd_nodelru_scan) {
				if ($stat eq $key) {
					$current_value += $value;
				}
			}
		} elsif ($subHeading eq "mmtests_kswapd_steal") {
        		foreach my $key (@mmtests_kswapd_steal) {
				if ($stat eq $key) {
					$current_value += $value;
				}
			}
		} elsif ($subHeading eq "mmtests_total_slab") {
			foreach my $key (@mmtests_slab) {
				if ($stat eq $key) {
					$current_value += $value;
				}
			}
		} elsif ($subHeading eq "mmtests_kswapd_efficiency" ) {
			my $scan = 0;
			my $steal = 0;
			foreach my $key (@mmtests_kswapd_scan) {
				if ($stat eq $key) {
					$current_scan += $value;
				}
			}
			foreach my $key (@mmtests_kswapd_steal) {
				if ($stat eq $key) {
					$current_steal += $value;
				}
			}
		} elsif ($subHeading eq "mmtests_hint_faults_remote") {
			if ($stat eq "numa_hint_faults") {
				$current_value += $value;
			}

			if ($stat eq "numa_hint_faults_local") {
				$current_value -= $value;
			}
		} elsif ($subHeading eq "mmtests_vmscan_write_file") {
			if ($stat eq "nr_vmscan_write") {
				$current_value += $value;
			}
			if ($stat eq "pswpout") {
				$current_value -= $value;
			}
		} elsif ($subHeading eq "mmtests_vmscan_write_anon") {
			if ($stat eq "pswpout") {
				$current_value += $value;
			}
		} elsif ($subHeading eq "mmtests_vmscan_process_pages") {
			if ($stat eq "nr_file_pages" || $stat eq "nr_anon_pages") {
				$current_value += $value;
			}
		} elsif ($subHeading eq "pgpgtotal") {
			foreach my $key ("pgpgin", "pgpgout") {
				if ($stat eq $key) {
					$current_value += $value;
				}
			}
		} elsif ($subHeading eq "mmtests_minor_faults") {
			if ($stat eq "pgfault") {
				$current_value += $value;
			}
			if ($stat eq "pgmajfault") {
				$current_value -= $value;
			}
		} elsif ($stat eq $subHeading) {
			$current_value = $value;
		}
	}

	if ($_fieldCounters{$subHeading} || $subHeading eq "mmtests_vmscan_process_pages") {
		return $current_value;
	} elsif ($subHeading eq "mmtests_total_anon") {
		$nr_thp_anon <<= 9;
		if ($nr_anon > $nr_thp_anon) {
			return $nr_anon;
		}
		return $nr_anon + $nr_thp_anon;
	} elsif ($subHeading eq "mmtests_total_slab") {
		return $current_value;
	} elsif ($subHeading eq "mmtests_direct_efficiency" ||
		 $subHeading eq "mmtests_kswapd_efficiency") {
		my ($delta_steal, $delta_scan);

		if ($self->{_LastStealValue}) {
			$delta_steal = $current_steal - $self->{_LastStealValue};
			$delta_scan  = $current_scan  - $self->{_LastScanValue};
		}

		$self->{_LastStealValue} = $current_steal;
		$self->{_LastScanValue}  = $current_scan;

		if ($delta_scan) {
			return $delta_steal * 100 / $delta_scan;
		} else {
			return 100;
		}
	} else {
		my $delta_value = 0;
		if ($self->{_LastValue}) {
			$delta_value = $current_value - $self->{_LastValue};
		}
		$self->{_LastValue} = $current_value;

		# Due to races it is possible PSWPOUT is updated before
		# VMSCAN_WRITE. Watch for misleading negative values for page
		# writes
		if ($subHeading eq "mmtests_vmscan_write_file" && $delta_value < 0) {
			$delta_value = 0;
		}

		return $delta_value;
	}
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my (%vmstat_before, %vmstat_after, %vmstat);
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $start_timestamp = 0;

	if ($subHeading eq "") {
		$subHeading = "pgpgin";
	}
	$self->{_Heading} = $subHeading;

	# TODO: Auto-discover lengths and handle multi-column reports
	my $fieldLength = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "time", $subHeading ];
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}d" ];

	my $file = "$reportDir/proc-vmstat-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	my $vmstat = "";
	while (<INPUT>) {
		if ($_ =~ /^time: ([0-9]+)/) {
			$timestamp = $1;
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			} else {
				push @{$self->{_ResultData}},
					[ $timestamp - $start_timestamp,
					  $self->parseVMStat($vmstat, $subHeading)
					];
				$vmstat = "";
			}
			next;
		}
		$vmstat .= $_;
	}
}

1;
