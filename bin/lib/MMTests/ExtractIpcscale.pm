# ExtractIpcscale.pm
package MMTests::ExtractIpcscale;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractIpcscale",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "Operations/sec,TestName,Latency,candlesticks";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_Opname} = "Latency";
	$self->SUPER::initialise();
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $recent = 0;

	my @files = <$reportDir/noprofile/semscale.*>;
	my %samples;
	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file");

		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /^Threads ([0-9]+), interleave ([0-9]+) threadspercore ([0-9]+) delay ([0-9]+): ([0-9]+) in ([0-9]+) secs/) {
				my $nr_threads = $1;
				my $interleave = $2;
				my $delay = $4;
				my $opSec = $5 / $6;

				if ($delay == 0) {
					my $op = "$nr_threads-i$interleave-d$delay";
					push @{$self->{_ResultData}}, [ $op, ++$samples{$op}, $opSec ];
				}
			}
		}
	}
	my @ops = sort {$a <=> $b} keys %samples;
	$self->{_Operations} = \@ops;
	close INPUT;
}

1;
