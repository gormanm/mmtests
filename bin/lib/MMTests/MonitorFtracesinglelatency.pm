# MonitorFtracesinglelatency.pm
package MMTests::MonitorFtracesinglelatency;
use MMTests::MonitorFtrace;
use MMTests::Stat;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

my ($regex_default);
my ($regex_watch, $regex_end);
my ($tracepoint_watch, $delay_field);
my $name_start;
my $start_timestamp;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_PlotXaxis} = "Time";
	$self->{_PlotType} = "points";
	$self->{_DataType} = DataTypes::DATA_TIME_MSECONDS;
	# Some modules using this define their own set of thresholds...
	if (!defined($self->{_SummaryStats})) {
		$self->{_SummaryStats} = [ "min", "percentile-25",
			"percentile-50", "percentile-75", "percentile-1",
			"percentile-5", "percentile-10", "percentile-90", 
			"percentile-95", "percentile-99", "max", "_mean",
			"samples", "samples-0,5", "samples-5,10",
			"samples-10,100", "samples-100,500", "samples-500,1000",
			"samples-1000,5000", "samples-5000,max" ];
	}
	$self->{_RatioSummaryStat} = [ "percentile-95" ];
	$self->SUPER::initialise($reportDir, $testName);
}

sub add_regex($$$$)
{
	my $self = shift @_;
	my $tracepoint = shift @_;
	my $def = shift @_;
	$delay_field = shift @_;

	$delay_field -= 1;
	$tracepoint_watch = $tracepoint;
	$tracepoint_watch =~ s/.*\///;
	$regex_watch = $self->generate_traceevent_regex($tracepoint, $def, @_);
}

sub add_regex_noverify($$)
{
	my $self = shift @_;
	$tracepoint_watch = shift @_;
	my $def = shift @_;
	$delay_field = $_;
	
	$tracepoint_watch =~ s/.*\///;
	$regex_watch = $def;
}
	
# By default, display everything
my $delay_threshold = -1;

# By default, assume units are in time
my $jiffie_multiplier = 1;

sub set_delay_threshold
{
	my $self = shift @_;
	$delay_threshold = shift @_;
}

sub set_jiffie_multiplier
{
	my $self = shift @_;
	$jiffie_multiplier = shift @_;
}

sub ftraceInit {
	my $self = shift @_;
	my @ftraceCounters;

	$self->{_FtraceCounters} = \@ftraceCounters;
}

sub ftraceCallback {
	my ($self, $timestamp_ms, $pid, $process, $tracepoint, $details) = @_;
	my $ftraceCounterRef = $self->{_FtraceCounters};
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
	if ($tracepoint eq $tracepoint_watch) {
		if ($details !~ /$regex_watch/p) {
			print "WARNING: Failed to parse $tracepoint as expected\n";
			print "	 $details\n";
			print "	 $regex_watch\n";
			return;
		}

		my @elements = split(/\s+/, $details);
		my $delayed = $elements[$delay_field];
		$delayed =~ s/.*=//;
		$delayed *= $jiffie_multiplier;

		if ($self->{_StartTimestampMs} == 0) {
			$self->{_StartTimestampMs} = $timestamp_ms;
		}

		if ($delayed > $delay_threshold) {
			$self->addData("latency", ($timestamp_ms - $self->{_StartTimestampMs}) / 1000, $delayed );
		}
	}
}

1;
