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

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_PlotXaxis} = "Time";
	$self->{_PlotType} = "points";
	$self->{_DataType} = DataTypes::DATA_TIME_MSECONDS;
	$self->{_SummaryStats} = [ "min", "percentile-25", "percentile-50",
		"percentile-75", "percentile-1", "percentile-5",
		"percentile-10", "percentile-90",  "percentile-95",
		"percentile-99", "max", "_mean", "samples", "samples-0,5",
		"samples-5,10", "samples-10,100", "samples-100,500",
		"samples-500,1000", "samples-1000,5000", "samples-5000,max" ];
	$self->{_RatioSummaryStat} = [ "percentile-95" ];
	$self->SUPER::initialise($subHeading);
}

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

sub ftraceInit {
	my $self = shift @_;
	my @ftraceCounters;
	my %perprocessStats;

	%latencyState = ();

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

1;
