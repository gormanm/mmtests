# MonitorFtraceextfrag.pm
package MMTests::MonitorFtraceextfrag;
use MMTests::MonitorFtrace;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

# Tracepoint events
use constant PAGE_ALLOC_EXTFRAG			=> 1;
use constant PAGE_ALLOC_EXTFRAG_BAD		=> 2;
use constant PAGE_ALLOC_EXTFRAG_UNMOVABLE	=> 3;
use constant PAGE_ALLOC_EXTFRAG_UNMOVABLE_MOVE	=> 4;
use constant EVENT_UNKNOWN			=> 5;

# Defaults for dynamically discovered regex's
my $regex_mm_page_alloc_extfrag_default = 'page=([0-9a-f]*) pfn=([0-9]*) alloc_order=([0-9]*) fallback_order=([0-9]*) pageblock_order=([0-9]*) alloc_migratetype=([0-9]*) fallback_migratetype=([0-9]*) fragmenting=([0-9]*) change_ownership=([0-9]*)';

# Dynamically discovered regex
my $regex_mm_page_alloc_extfrag;

my @_fieldIndexMap;
$_fieldIndexMap[PAGE_ALLOC_EXTFRAG]			= "page_alloc_extfrag";
$_fieldIndexMap[PAGE_ALLOC_EXTFRAG_BAD]			= "page_alloc_extfrag_bad";
$_fieldIndexMap[PAGE_ALLOC_EXTFRAG_UNMOVABLE]		= "page_alloc_extfrag_unmovable";
$_fieldIndexMap[PAGE_ALLOC_EXTFRAG_UNMOVABLE_MOVE]	= "page_alloc_extfrag_unmovable_move";
$_fieldIndexMap[EVENT_UNKNOWN]				= "event_unknown";

my %_fieldNameMap = (
	"page_alloc_extfrag"			=> "Page alloc extfrag event",
	"page_alloc_extfrag_bad"		=> "Extfrag fragmenting",
	"page_alloc_extfrag_unmovable"		=> "Extfrag for unmovable",
	"page_alloc_extfrag_unmovable_move"	=> "Extfrag unmovable placed with movable",
	"event_unknown"				=> "Unrecognised events",
);

sub ftraceInit {
	my $self = $_[0];
	$regex_mm_page_alloc_extfrag = $self->generate_traceevent_regex(
		"kmem/mm_page_alloc_extfrag",
		$regex_mm_page_alloc_extfrag_default,
		"page", "pfn", "alloc_order", "fallback_order", "pageblock_order", "alloc_migratetype", "fallback_migratetype", "fragmenting", "change_ownership");

	$self->{_FieldLength} = 16;

	my @ftraceCounters;
	$self->{_FtraceCounters} = \@ftraceCounters;
}

sub ftraceCallback {
	my ($self, $timestamp, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};

	if ($tracepoint eq "mm_page_alloc_extfrag") {
		if ($details !~ /$regex_mm_page_alloc_extfrag/p) {
			print "WARNING: Failed to parse mm_page_alloc_extfrag as expected\n";
			print "	 $details\n";
			print "	 $regex_mm_page_alloc_extfrag\n";
			return;
		}

		# Fields (look at the regex)
		# 6: alloc_migratetype
		# 7: fallback_migratetype
		# 8: fragmenting

		@$ftraceCounterRef[PAGE_ALLOC_EXTFRAG]++;
		if ($6 == 0) {
			@$ftraceCounterRef[PAGE_ALLOC_EXTFRAG_UNMOVABLE]++;
		}
		if ($6 == 0 && $7 == 2) {
			@$ftraceCounterRef[PAGE_ALLOC_EXTFRAG_UNMOVABLE_MOVE]++;
		}
		if ($8 != 0) {
			@$ftraceCounterRef[PAGE_ALLOC_EXTFRAG_BAD]++;
		}
	} else {
		@$ftraceCounterRef[EVENT_UNKNOWN]++;
	}
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

		push @{$self->{_ResultData}}, [ $keyName, 0, $ftraceCounterRef->[$key] ];
	}

	$self->{_FieldHeaders} = [ "Op", "Value" ];
	$self->{_FieldFormat} = [ "%-$self->{_FieldLength}s", "", "%12d" ];
}

1;
