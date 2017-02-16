# MonitorFtracesinglelatency.pm
package MMTests::MonitorFtracesinglelatency;
use MMTests::MonitorFtrace;
use VMR::Stat;
our @ISA = qw(MMTests::MonitorFtrace);
use strict;

my ($regex_default);
my ($regex_watch, $regex_end);
my ($tracepoint_watch, $delay_field);
my $name_start;
my $start_timestamp;

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

my @thresholds = ( 0, 5, 10, 100, 500, 1000, 5000 );

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

sub set_thresholds
{
	my $self = shift @_;
	@thresholds = @_;
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

	$self->{_FieldLength} = 12;
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
			push @{$self->{_ResultData}}, [ ($timestamp_ms - $self->{_StartTimestampMs}) / 1000, $delayed ];
		}
	}
}

sub extractSummary() {
	my $self = shift @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_RowOrientated} = 0;
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}.4f", ];
	$self->{_SummaryLength} = 12;
	$self->{_SummaryHeaders} = [ "Latency", "" ];

	my @samples;
	for (my $i; $i <= $#thresholds; $i++) {
		$samples[$i] = 0;
	}

	my @units;
	foreach my $row (@data) {
		push @units, @{$row}[1];

		for (my $i = 0; $i <= $#thresholds; $i++) {
			if (@{$row}[1] >= $thresholds[$i] && ($i == $#thresholds || @{$row}[1] < $thresholds[$i+1])) {
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
