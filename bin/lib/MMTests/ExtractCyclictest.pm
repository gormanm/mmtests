# ExtractCyclictest.pm
package MMTests::ExtractCyclictest;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractCyclictest",
		_PlotYaxis   => DataTypes::LABEL_TIME_USECONDS,
		_PlotType    => "simple",
		_PlotStripSubheading => 1,
		_SingleType  => 1,
		_PlotXaxis   => "CPU",
		_Opname      => "Lat",
	};
	bless $self, $class;
	return $self;
}

# Traditional format
sub parseTraditional($$) {
	my ($self, $reportDir) = @_;
	my $input = $self->SUPER::open_log("$reportDir/cyclictest.log");
	while (<$input>) {
		next if ($_ !~ /^T: ([0-9+]) .*Avg:\s+([0-9]+).*Max:\s+([0-9]+)/);
		my $cpu = $1;
		$cpus_seen{$cpu} = 1;
		$self->addData("Avg-$cpu", 0, $2);
		$self->addData("Max-$cpu", 0, $3);
	}
	close $input;

	my @operations;
	foreach my $metric ("Avg", "Max") {
		foreach my $cpu (sort keys %cpus_seen) {
			push @operations, "$metric-$cpu";
		}
	}
	$self->{_Operations} = \@operations;
}

sub parseHistogram($$) {
	my ($self, $reportDir) = @_;
	my $input = $self->SUPER::open_log("$reportDir/cyclictest-histogram.log");
	while (<$input>) {
		my $line = $_;
		my $op;
		my $resultsStr;
		if ($line =~ /^# (...) Latencies: (.*)/) {
			$op = $1;
			$results = $2;
		} elsif ($line =~ /^# Histogram Overflows: (.*)/) {
			$op = "Overflow";
			$results = $1;
		} else {
			next;
		}

		my @resultsArr = split(/ /, $results);
		for (my $cpu = 0; $cpu < $#resultsArr; $cpu++) {
			$resultsArr[$cpu] =~ s/^0+//;
			$self->addData("$op-$cpu", 0, $resultsArr[$cpu]);
		}
	}
	close $input;
}

my %cpus_seen;
sub extractReport() {
	my ($self, $reportDir) = @_;

	$self->{_Precision} = 0;
	if (-e "$reportDir/cyclictest.log") {
		parseTraditional($self, $reportDir);
	} else {
		parseHistogram($self, $reportDir);
	}
}

1;
