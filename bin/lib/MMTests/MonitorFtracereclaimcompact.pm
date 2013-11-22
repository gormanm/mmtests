# MonitorFtracereclaimcompact.pm
package MMTests::MonitorFtracereclaimcompact;
use MMTests::MonitorFtrace;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

# Tracepoint events
use constant WRITEBACK_CONGESTION_WAIT          => 1;
use constant WRITEBACK_WAIT_IFF_CONGESTED       => 2;
use constant VMSCAN_LRU_SHRINK_INACTIVE		=> 3;
use constant VMSCAN_SHRINK_SLAB_START		=> 5;
use constant VMSCAN_SHRINK_SLAB_END		=> 6;
use constant VMSCAN_DIRECT_RECLAIM_BEGIN	=> 7;
use constant VMSCAN_DIRECT_RECLAIM_END		=> 8;
use constant VMSCAN_KSWAPD_WAKE			=> 9;
use constant VMSCAN_KSWAPD_SLEEP		=> 10;
use constant COMPACTION_BEGIN			=> 11;
use constant COMPACTION_END			=> 12;

use constant WRITEBACK_CONGESTION_WAIT_TIME_WAITED		=>13;
use constant WRITEBACK_CONGESTION_WAIT_TIME_WAITED_DIRECT	=>14;
use constant WRITEBACK_CONGESTION_WAIT_TIME_WAITED_KSWAPD	=>15;
use constant WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED		=>16;
use constant WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_DIRECT	=>17;
use constant WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_KSWAPD	=>18;
use constant VMSCAN_LRU_SHRINK_DIRECT				=>19;
use constant VMSCAN_SLAB_SHRINK_DIRECT				=>20;
use constant VMSCAN_LRU_SHRINK_KSWAPD				=>21;
use constant VMSCAN_SLAB_SHRINK_KSWAPD				=>22;
use constant VMSCAN_LRU_RECLAIMED_RATIO				=>23;
use constant VMSCAN_SLAB_SHRINK_DIRECT_TIME_STALLED		=>24;
use constant VMSCAN_SLAB_SHRINK_KSWAPD_TIME_STALLED		=>25;
use constant VMSCAN_DIRECT_RECLAIM_TIME_STALLED			=>26;
use constant VMSCAN_KSWAPD_TIME_AWAKE				=>27;

use constant EVENT_UNKNOWN			=> 26;

# Defaults for dynamically discovered regex's
my $regex_writeback_congestion_wait_default    = 'usec_timeout=([0-9]*) usec_delayed=([0-9]*)';
my $regex_writeback_wait_iff_congested_default = 'usec_timeout=([0-9]*) usec_delayed=([0-9]*)';
my $regex_vmscan_lru_shrink_inactive_default   = 'nid=([0-9]*) zid=([0-9]*) nr_scanned=([0-9]*) nr_reclaimed=([0-9]*) priority=([0-9]*) flags=([0-9]*)';
my $regex_vmscan_shrink_slab_start_default     = '([0-9a-fx]+)F (([0-9a-fx]): objects to shrink ([0-9]*) gfp_flags ([A-Z|_]+) pgs_scanned ([0-9]*) lru_pgs ([0-9]*) cache items ([0-9]*) delta ([0-9]*) total_scan ([0-9]*)';
my $regex_vmscan_shrink_slab_end_default       = '([0-9a-fx]+)F (([0-9a-fx]): unused scan count ([0-9]*) new scan count ([0-9]*) total_scan ([0-9]*) last shrinker return val ([0-9]*)"';
my $regex_vmscan_direct_reclaim_begin_default  = 'order=([0-9]*) may_writepage=([0-9]*) gfp_flags=([A-Z_|]+)';
my $regex_vmscan_direct_reclaim_end_default    = 'nr_reclaimed=([0-9]*)';
my $regex_vmscan_kswapd_wake_default           = 'nid=([0-9]*) order=([0-9]*)';
my $regex_vmscan_kswapd_sleep_default          = 'nid=([0-9]*)';
my $regex_compaction_begin_default             = 'zone_start=([0-9]*) migrate_start=([0-9]*) zone_end=([0-9]*) free_start=([0-9]*)';
my $regex_compaction_end_default               = 'status=([0-9]*)';

# Dynamically discovered regex
my $regex_writeback_congestion_wait;
my $regex_writeback_wait_iff_congested;
my $regex_vmscan_lru_shrink_inactive;
my $regex_vmscan_shrink_slab_start;
my $regex_vmscan_shrink_slab_end;
my $regex_vmscan_direct_reclaim_begin;
my $regex_vmscan_direct_reclaim_end;
my $regex_vmscan_kswapd_wake;
my $regex_vmscan_kswapd_sleep;
my $regex_compaction_begin;
my $regex_compaction_end;

my @_fieldIndexMap;
$_fieldIndexMap[WRITEBACK_CONGESTION_WAIT]			= "writeback_congestion_wait";
$_fieldIndexMap[WRITEBACK_CONGESTION_WAIT_TIME_WAITED]		= "writeback_congestion_wait_time";
$_fieldIndexMap[WRITEBACK_CONGESTION_WAIT_TIME_WAITED_DIRECT]	= "writeback_congestion_wait_time_direct";
$_fieldIndexMap[WRITEBACK_CONGESTION_WAIT_TIME_WAITED_KSWAPD]	= "writeback_congestion_wait_time_kswapd";
$_fieldIndexMap[WRITEBACK_WAIT_IFF_CONGESTED]			= "writeback_wait_iff_congested";
$_fieldIndexMap[WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED]	= "writeback_wait_iff_congested_time";
$_fieldIndexMap[WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_DIRECT]= "writeback_wait_iff_congested_time_direct";
$_fieldIndexMap[WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_KSWAPD]= "writeback_wait_iff_congested_time_kswapd";
$_fieldIndexMap[VMSCAN_LRU_SHRINK_DIRECT] =                       "vmscan_lru_shrink_direct";
$_fieldIndexMap[VMSCAN_SLAB_SHRINK_DIRECT] =                      "vmscan_slab_shrink_direct";
$_fieldIndexMap[VMSCAN_LRU_SHRINK_KSWAPD] =                       "vmscan_lru_shrink_kswapd";
$_fieldIndexMap[VMSCAN_SLAB_SHRINK_KSWAPD] =                      "vmscan_slab_shrink_kswapd";
$_fieldIndexMap[VMSCAN_LRU_RECLAIMED_RATIO] =                     "vmscan_lru_reclaimed_ratio";
$_fieldIndexMap[VMSCAN_SLAB_SHRINK_DIRECT_TIME_STALLED] =         "vmscan_slab_shrink_direct_time_stalled";
$_fieldIndexMap[VMSCAN_SLAB_SHRINK_KSWAPD_TIME_STALLED] =         "vmscan_slab_shrink_kswapd_time_stalled";
$_fieldIndexMap[VMSCAN_DIRECT_RECLAIM_TIME_STALLED] =             "vmscan_direct_reclaim_time_stalled";
$_fieldIndexMap[VMSCAN_KSWAPD_TIME_AWAKE] =                       "vmscan_kswapd_time_awake";
$_fieldIndexMap[COMPACTION_DIRECT_STALLED] =                      "compaction_direct_time_stalled";
$_fieldIndexMap[COMPACTION_KSWAPD_STALLED] =                      "compaction_kswapd_time_stalled";
$_fieldIndexMap[EVENT_UNKNOWN] =                                  "event_unknown";

my %_fieldNameMap = (
	"writeback_congestion_wait"			=> "FullCongest waits",
	"writeback_congestion_wait_time"		=> "FullCongest time waited",
	"writeback_congestion_wait_time_direct"		=> "FullCongest direct waited",
	"writeback_congestion_wait_time_kswapd"		=> "FullCongest kswapd waited",
	"writeback_wait_iff_congested"			=> "ConditionalCongest waits",
	"writeback_wait_iff_congested_time"		=> "CondCongest time waited",
	"writeback_wait_iff_congested_time_direct"	=> "CondCongest direct waited",
	"writeback_wait_iff_congested_time_kswapd"	=> "CondCongest kswapd waited",
	"vmscan_lru_shrink_direct"                      => "Direct reclaimed LRU pages",
	"vmscan_slab_shrink_direct"			=> "Direct reclaimed Slab pages",
	"vmscan_lru_shrink_kswapd"			=> "Kswapd reclaimed LRU pages",
	"vmscan_slab_shrink_kswapd"			=> "Kswapd reclaimed Slab pages",
	"vmscan_lru_reclaimed_ration"			=> "Ratio LRU/Slab",
	"vmscan_direct_reclaim_time_stalled"            => "Time direct reclaim stalled",
        "vmscan_slab_shrink_direct_time_stalled"	=> "Time direct slab shrink",
        "vmscan_slab_shrink_kswapd_time_stalled"	=> "Time kswapd slab shrink",
	"vmscan_kswapd_time_awake"			=> "Time kswapd awake",
	"compaction_direct_time_stalled"		=> "Time direct compacting",
	"compaction_kswapd_time_stalled"		=> "Time kswapd compacting",
	"event_unknown"					=> "Unrecognised events",
);

my %shrinkSlabState;
my %directReclaimState;
my %kswapdState;
my %compactionState;

sub ftraceInit {
	my $self = $_[0];
	$regex_writeback_congestion_wait = $self->generate_traceevent_regex(
		"kmem/writeback_congestion_wait",
		$regex_writeback_congestion_wait_default,
		"usec_timeout", "usec_delayed");
	$regex_writeback_wait_iff_congested = $self->generate_traceevent_regex(
		"kmem/writeback_wait_iff_congested",
		$regex_writeback_wait_iff_congested_default,
		"usec_timeout", "usec_delayed");
	$regex_vmscan_lru_shrink_inactive = $self->generate_traceevent_regex(
		"vmscan/mm_vmscan_lru_shrink_inactive",
		$regex_vmscan_lru_shrink_inactive_default,
		"nid", "zid", "nr_scanned", "nr_reclaimed", "priority", "flags");
	$regex_vmscan_direct_reclaim_begin = $self->generate_traceevent_regex(
		"vmscan/mm_vmscan_direct_reclaim_begin",
		$regex_vmscan_direct_reclaim_begin_default,
		"order", "may_writepage", "gfp_flags");
	$regex_vmscan_direct_reclaim_end = $self->generate_traceevent_regex(
		"vmscan/mm_vmscan_direct_reclaim_end",
		$regex_vmscan_direct_reclaim_end_default,
		"nr_reclaimed");
	$regex_vmscan_kswapd_wake = $self->generate_traceevent_regex(
		"vmscan/mm_vmscan_kswapd_wake",
		$regex_vmscan_kswapd_wake_default,
		"nid", "order");
	$regex_vmscan_kswapd_sleep = $self->generate_traceevent_regex(
		"vmscan/mm_vmscan_kswapd_sleep",
		$regex_vmscan_kswapd_sleep_default,
		"nid");
	$regex_compaction_begin = $self->generate_traceevent_regex(
		"compaction/mm_compaction_begin",
		$regex_compaction_begin_default,
		"zone_start", "migrate_start", "zone_end", "free_start");
	$regex_compaction_end = $self->generate_traceevent_regex(
		"compaction/mm_compaction_end",
		$regex_compaction_end_default,
		"status");

	# Non-standard format for mm-based tracepoints
	$regex_vmscan_shrink_slab_start = $regex_vmscan_shrink_slab_start_default;
	$regex_vmscan_shrink_slab_end = $regex_vmscan_shrink_slab_end_default;

	$self->{_FieldLength} = 16;

	my @ftraceCounters;
	my %perprocessStats;
	$self->{_FtraceCounters} = \@ftraceCounters;
	$self->{_PerProcessStats} = \%perprocessStats;

	%shrinkSlabState = ();
	%directReclaimState = ();
	%kswapdState = ();
	%compactionState = ();
}

# Convert sec.usec timestamp format
sub timestamp_to_ms($) {
	my $timestamp = $_[0];

	my ($sec, $usec) = split (/\./, $timestamp);
	return ($sec * 1000) + ($usec / 1000);
}

sub ftraceCallback {
	my ($self, $timestamp, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};
	my $perprocessRef = $self->{_PerProcessStats};
	my $pidprocess = "$pid-$process";
	my $timestamp_ms = timestamp_to_ms($timestamp);

	if ($tracepoint eq "writeback_congestion_wait") {
		if ($details !~ /$regex_writeback_congestion_wait/p) {
			print "WARNING: Failed to parse writeback_congestion_wait as expected\n";
			print "	 $details\n";
			print "	 $regex_writeback_congestion_wait\n";
			return;
		}

		@$ftraceCounterRef[WRITEBACK_CONGESTION_WAIT]++;

		# Fields (look at the regex)
		# $2 == usec_delayed
		@$ftraceCounterRef[WRITEBACK_CONGESTION_WAIT_TIME_WAITED] += $2;
		$perprocessRef->{$process}->{WRITEBACK_CONGESTION_WAIT_TIME_WAITED} += $2;
		if ($process =~ /kswapd[0-9]+-/) {
			@$ftraceCounterRef[WRITEBACK_CONGESTION_WAIT_TIME_WAITED_KSWAPD] += $2;
			$perprocessRef->{$process}->{WRITEBACK_CONGESTION_WAIT_TIME_WAITED_KSWAPD} += $2;
		} else {
			@$ftraceCounterRef[WRITEBACK_CONGESTION_WAIT_TIME_WAITED_DIRECT] += $2;
			$perprocessRef->{$process}->{WRITEBACK_CONGESTION_WAIT_TIME_WAITED_DIRECT} += $2;
		}

	} elsif ($tracepoint eq "writeback_wait_iff_congested") {
		if ($details !~ /$regex_writeback_wait_iff_congested/p) {
			print "WARNING: Failed to parse writeback_wait_iff_congested as expected\n";
			print "	 $details\n";
			print "	 $regex_writeback_wait_iff_congested\n";
			return;
		}

		@$ftraceCounterRef[WRITEBACK_WAIT_IFF_CONGESTED]++;

		# Fields (look at the regex)
		@$ftraceCounterRef[WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED] += $2;
		$perprocessRef->{$process}->{WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED} += $2;
		if ($process =~ /kswapd[0-9]+-/) {
			@$ftraceCounterRef[WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_KSWAPD] += $2;
			$perprocessRef->{$process}->{WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_KSWAPD} += $2;
		} else {
			@$ftraceCounterRef[WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_DIRECT] += $2;
			$perprocessRef->{$process}->{WRITEBACK_WAIT_IFF_CONGESTED_TIME_WAITED_DIRECT} += $2;
		}
	} elsif ($tracepoint eq "mm_vmscan_lru_shrink_inactive") {
		if ($details !~ /$regex_vmscan_lru_shrink_inactive/p) {
			print "WARNING: Failed to parse mm_vmscan_lru_shrink_inactive as expected\n";
			print "	 $details\n";
			print "	 $regex_vmscan_lru_shrink_inactive\n";
			return;
		}

		# Fields (look at the regex)
		if ($process =~ /kswapd[0-9]+-/) {
			@$ftraceCounterRef[VMSCAN_LRU_SHRINK_KSWAPD] += $4;
		} else {
			@$ftraceCounterRef[VMSCAN_LRU_SHRINK_DIRECT] += $4;
		}
	} elsif ($tracepoint eq "mm_vmscan_kswapd_wake") {
		if ($details !~ /$regex_vmscan_kswapd_wake/p) {
			print "WARNING: Failed to parse mm_vmscan_kswapd_wake as expected\n";
			print "	 $details\n";
			print "	 $regex_vmscan_kswapd_wake\n";
			return;
		}

		$kswapdState{$pidprocess} = $timestamp_ms;

		# Fields (look at the regex)
	} elsif ($tracepoint eq "mm_vmscan_kswapd_sleep") {
		if ($details !~ /$/p) {
			print "WARNING: Failed to parse mm_vmscan_kswapd_sleep as expected\n";
			print "	 $details\n";
			print "	 $regex_vmscan_kswapd_sleep\n";
			return;
		}

		# Check how long the process was stalled
		my $delayed = 0;
		if ($kswapdState{$pidprocess}) {
			$delayed = $kswapdState{$pidprocess} - $timestamp_ms;
		}
		$directReclaimState{$pidprocess} = 0;

		# Fields (look at the regex)
		@$ftraceCounterRef[VMSCAN_KSWAPD_TIME_AWAKE] += $delayed;

	} elsif ($tracepoint eq "mm_vmscan_direct_reclaim_begin") {
		if ($details !~ /$regex_vmscan_direct_reclaim_begin/p) {
			print "WARNING: Failed to parse mm_vmscan_direct_reclaim_begin as expected\n";
			print "	 $details\n";
			print "	 $regex_vmscan_direct_reclaim_begin\n";
			return;
		}

		$directReclaimState{$pidprocess} = $timestamp_ms;

		# Fields (look at the regex)
	} elsif ($tracepoint eq "mm_vmscan_direct_reclaim_end") {
		if ($details !~ /$/p) {
			print "WARNING: Failed to parse mm_vmscan_direct_reclaim_end as expected\n";
			print "	 $details\n";
			print "	 $regex_vmscan_direct_reclaim_end\n";
			return;
		}

		# Check how long the process was stalled
		my $delayed = 0;
		if ($directReclaimState{$pidprocess}) {
			$delayed = $directReclaimState{$pidprocess} - $timestamp_ms;
		}
		$directReclaimState{$pidprocess} = 0;

		# Fields (look at the regex)
		@$ftraceCounterRef[VMSCAN_DIRECT_RECLAIM_TIME_STALLED] += $delayed;
	} elsif ($tracepoint eq "mm_shrink_slab_start") {
		if ($details !~ /$regex_vmscan_shrink_slab_start/p) {
			print "WARNING: Failed to parse mm_shrink_slab_start as expected\n";
			print "	 $details\n";
			print "	 $regex_vmscan_shrink_slab_start\n";
			return;
		}

		$shrinkSlabState{$pidprocess} = $timestamp_ms;

		# Fields (look at the regex)
	} elsif ($tracepoint eq "mm_shrink_slab_end") {
		if ($details !~ /$/p) {
			print "WARNING: Failed to parse mm_shrink_slab_end as expected\n";
			print "	 $details\n";
			print "	 $regex_vmscan_shrink_slab_end\n";
			return;
		}

		# Check how long the process was stalled
		my $delayed = 0;
		if ($shrinkSlabState{$pidprocess}) {
			$delayed = $shrinkSlabState{$pidprocess} - $timestamp_ms;
		}
		$shrinkSlabState{$pidprocess} = 0;

		# Fields (look at the regex)
		if ($process =~ /kswapd[0-9]+-/) {
			@$ftraceCounterRef[VMSCAN_SLAB_SHRINK_KSWAPD] += $6;
			@$ftraceCounterRef[VMSCAN_SLAB_SHRINK_KSWAPD_TIME_STALLED] += $delayed;
		} else {
			@$ftraceCounterRef[VMSCAN_SLAB_SHRINK_DIRECT] += $6;
			@$ftraceCounterRef[VMSCAN_SLAB_SHRINK_DIRECT_TIME_STALLED] += $delayed;
		}
	} elsif ($tracepoint eq "mm_compaction_begin") {
		if ($details !~ /$regex_compaction_begin/p) {
			print "WARNING: Failed to parse mm_compaction_begin as expected\n";
			print "	 $details\n";
			print "	 $regex_compaction_begin\n";
			return;
		}

		$directReclaimState{$pidprocess} = $timestamp_ms;

		# Fields (look at the regex)
	} elsif ($tracepoint eq "mm_compaction_end") {
		if ($details !~ /$/p) {
			print "WARNING: Failed to parse mm_compaction_end as expected\n";
			print "	 $details\n";
			print "	 $regex_compaction_end\n";
			return;
		}

		# Check how long the process was stalled
		my $delayed = 0;
		if ($compactionState{$pidprocess}) {
			$delayed = $compactionState{$pidprocess} - $timestamp_ms;
		}
		$compactionState{$pidprocess} = 0;

		# Fields (look at the regex)
		@$ftraceCounterRef[COMPACTION_DIRECT_STALLED] += $delayed;
	} else {
		@$ftraceCounterRef[EVENT_UNKNOWN]++;
	}

	my $lru_pages_shrink  = @$ftraceCounterRef[VMSCAN_LRU_SHRINK_DIRECT]  + @$ftraceCounterRef[VMSCAN_LRU_SHRINK_KSWAPD];
	my $slab_pages_shrink = @$ftraceCounterRef[VMSCAN_SLAB_SHRINK_DIRECT] + @$ftraceCounterRef[VMSCAN_SLAB_SHRINK_KSWAPD];
	@$ftraceCounterRef[VMSCAN_LRU_RECLAIMED_RATIO] = $lru_pages_shrink / ($lru_pages_shrink + $slab_pages_shrink);
}

sub ftraceReport { 
	my ($self, $rowOrientated) = @_;
	my $i;
	my (@headers, @fields, @format);
	my $ftraceCounterRef = $self->{_FtraceCounters};

	push @headers, "Unit";
	push @fields, 0;
	push @format, "";

	for (my $key = 0; $key < EVENT_UNKNOWN; $key++) {
		if (!defined($_fieldIndexMap[$key])) {
			next;
		}

		my $keyName = $_fieldIndexMap[$key];
		if ($rowOrientated && $_fieldNameMap{$keyName}) {
			$keyName = $_fieldNameMap{$keyName};
		}

		push @headers, $keyName;
		push @fields, @$ftraceCounterRef[$key];
		push @format, "%12d";
	}

	$self->{_FieldHeaders} = \@headers;
	$self->{_RowFieldFormat} = \@format;
	push @{$self->{_ResultData}}, \@fields;
}

1;
