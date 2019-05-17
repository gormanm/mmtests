# MonitorKcacheslabs.pm
package MMTests::MonitorKcacheslabs;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName    => "MonitorKcacheslabs",
		_DataType      => DataTypes::DATA_OPS_PER_SECOND,
		_FieldLength   => 24,
		_PlotType      => "simple",
		_PlotXaxis     => "Time"
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my ($reading_before, $reading_after);
	my $elapsed_time;
	my $timestamp;
	my $format;
	my $start_timestamp = 0;

	my ($subHeading, $subSummary) = split(/-/, $subHeading);

	my $file = "$reportDir/kcache-slabs-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	my $allocs = 0;
	my $frees = 0;
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		$line =~ s/^\s+//;

		if ($line =~ /^time: ([0-9]+)/) {
			if ($start_timestamp == 0) {
				$start_timestamp = $1;
			} else {
				$self->addData("allocs", $timestamp - $start_timestamp, $allocs );
				$self->addData("frees", $timestamp - $start_timestamp, $frees );
				$allocs = 0;
				$frees = 0;
			}
			$timestamp = $1;
			next;
		}
		
		if (($line =~ /^total kmem_cache_alloc/ || $line =~ /^total kmallocs/) && ($subHeading eq "" || $subHeading eq "allocs")) {
			my @elements = split(/\s+/, $line);
			$elements[-1] =~ s/\/sec//;
			$allocs += $elements[-1];
		}

		if (($line =~ /^total kmem_cache_frees/ || $line =~ /^total kfrees/) && ($subHeading eq "" || $subHeading eq "frees")) {
			my @elements = split(/\s+/, $line);
			$elements[-1] =~ s/\/sec//;
			$frees += $elements[-1];
		}
	}

	my @operations = ( "allocs", "frees");
	$self->{_Operations} = \@operations;
}

1;
