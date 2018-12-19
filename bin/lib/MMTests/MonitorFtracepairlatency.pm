# MonitorFtracepairlatency.pm
package MMTests::MonitorFtracepairlatency;
use MMTests::MonitorFtrace;
use MMTests::Stat;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

my ($regex_default_start, $regex_default_end);
my ($regex_start, $regex_end);
my ($tracepoint_start, $tracepoint_end);
my $name_start;
my $start_timestamp;
my %latencyState;

use constant LATENCY_START	=> 0;
use constant LATENCY_END	=> 1;
use constant LATENCY_STALLED	=> 2;

sub add_regex_start($$$)
{
	my $self = shift @_;
	my $tracepoint = shift @_;
	my $def = shift @_;

	$tracepoint_start = $tracepoint;
	$tracepoint_start =~ s/.*\///;

	$regex_start = $self->generate_traceevent_regex($tracepoint, $def, @_);
}

sub add_regex_start_noverify($$)
{
	my $self = shift @_;
	my $tracepoint = shift @_;
	my $def = shift @_;

	$tracepoint_start = $tracepoint;
	$tracepoint_start =~ s/.*\///;
	$regex_start = $def;
}
	
sub add_regex_end($$$)
{
	my $self = shift @_;
	my $tracepoint = shift @_;
	my $def = shift @_;

	$tracepoint_end = $tracepoint;
	$tracepoint_end =~ s/.*\///;

	$regex_end = $self->generate_traceevent_regex($tracepoint, $def, @_);
}

sub add_regex_end_noverify($$)
{
	my $self = shift @_;
	my $tracepoint = shift @_;
	my $def = shift @_;

	$tracepoint_end = $tracepoint;
	$tracepoint_end =~ s/.*\///;
	$regex_end = $tracepoint;
}

# By default, display everything
my $delay_threshold = -1;

sub set_delay_threshold
{
	my $self = shift @_;
	$delay_threshold = shift @_;
}

sub printDataType() {
	my ($self) = @_;

	print "ms,Time,Latency,points\n";
}

sub printPlot() {
	my ($self, $subheading) = @_;
	$self->printReport($subheading);
}

sub ftraceInit {
	my $self = shift @_;
	my @ftraceCounters;
	my %perprocessStats;

	%latencyState = ();

	$self->{_FieldLength} = 12;
	$self->{_FieldFormat} = [ "%-$self->{_FieldLength}s", "", "%$self->{_FieldLength}d" ];
	$self->{_FtraceCounters} = \@ftraceCounters;
	$self->{_PerProcessStats} = \%perprocessStats;
}

sub ftraceCallback {
	my ($self, $timestamp_ms, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};
	my $perprocessRef = $self->{_PerProcessStats};
	my $pidprocess = "$pid-$process";

	if ($self->{_SubHeading} eq "kswapd") {
		return if $process !~ /^kswapd[0-9]*$/;
	}
	if ($self->{_SubHeading} eq "khugepaged") {
		return if $process !~ /^khugepaged*$/;
	}
	if ($self->{_SubHeading} eq "no-kswapd") {
		return if $process =~ /^kswapd[0-9]*$/;
	}
	if ($self->{_SubHeading} eq "kswapd-kcompactd") {
		return if $process !~ /^kswapd[0-9]*$/ && $process !~ /^kcompactd[0-9]*$/;
	}
	if ($self->{_SubHeading} eq "no-kswapd-kcompactd-khugepaged") {
		return if $process =~ /^kswapd[0-9]*$/;
		return if $process =~ /^kcompactd[0-9]*$/;
		return if $process =~ /^khugepaged[0-9]*$/;
	}
	if ($tracepoint eq $tracepoint_start) {
		if ($details !~ /$regex_start/p) {
			print "WARNING: Failed to parse $tracepoint as expected\n";
			print "	 $details\n";
			print "	 $regex_start\n";
			return;
		}

		$latencyState{$pidprocess} = $timestamp_ms;
		if ($self->{_StartTimestampMs} == 0) {
			$self->{_StartTimestampMs} = $timestamp_ms;
		}
	} elsif ($tracepoint eq $tracepoint_end) {
		if ($details !~ /$/p) {
			print "WARNING: Failed to parse $tracepoint_end as expected\n";
			print "	 $details\n";
			print "	 $regex_end\n";
			return;
		}

		# Check how long the process was stalled
		my $delayed = 0;
		if ($latencyState{$pidprocess}) {
			$delayed = $timestamp_ms - $latencyState{$pidprocess};
			if ($delayed > $delay_threshold) {
				$self->addData("delay", ($latencyState{$pidprocess} - $self->{_StartTimestampMs}) / 1000, $delayed );
			}
		}
		$latencyState{$pidprocess} = 0;
	}
}

sub extractSummary() {
	my $self = shift @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.4f", ];
	$self->{_SummaryLength} = 12;
	$self->{_SummaryHeaders} = [ "Latency", "" ];

	my @thresholds = ( 0, 5, 10, 100, 500, 1000, 5000 );
	my @samples;
	for (my $i; $i <= $#thresholds; $i++) {
		$samples[$i] = 0;
	}

	my @units;
	foreach my $row (@data) {
		push @units, @{$row}[2];

		for (my $i = 0; $i <= $#thresholds; $i++) {
			if (@{$row}[2] >= $thresholds[$i] && ($i == $#thresholds || @{$row}[2] < $thresholds[$i+1])) {
				$samples[$i]++;
			}
		}
	}

	if ($#units == -1) {
		$units[0] = 0;
	}

	my $quartilesRef = calc_quartiles(@units);
	my @quartiles = @{$quartilesRef};

	my @row;
	push @{$self->{_SummaryData}}, [ "Min", calc_min(@units) ];
	push @{$self->{_SummaryData}}, [ "1st-qrtle", $quartiles[1]  ];
	push @{$self->{_SummaryData}}, [ "2nd-qrtle", $quartiles[2]  ];
	push @{$self->{_SummaryData}}, [ "3rd-qrtle", $quartiles[3]  ];
	push @{$self->{_SummaryData}}, [ "Max-90%",   $quartiles[90] ];
	push @{$self->{_SummaryData}}, [ "Max-93%",   $quartiles[93] ];
	push @{$self->{_SummaryData}}, [ "Max-95%",   $quartiles[95] ];
	push @{$self->{_SummaryData}}, [ "Max-99%",   $quartiles[99] ];
	push @{$self->{_SummaryData}}, [ "Max",       $quartiles[4]  ];
	push @{$self->{_SummaryData}}, [ "Mean",      calc_mean(@units) ];
	push @{$self->{_SummaryData}}, [ "Samples",   $#units ];
	for (my $i = 0; $i <= $#thresholds; $i++) {
		push @{$self->{_SummaryData}}, [ "Samples-$thresholds[$i]", $samples[$i] ];
	}

	return 1;
}

1;
