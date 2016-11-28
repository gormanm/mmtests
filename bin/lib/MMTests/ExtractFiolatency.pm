# ExtractFiolatency
package MMTests::ExtractFiolatency;
use MMTests::SummariseVariabletime;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "Fiolatency.pm",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_ResultData  => [],
		_PlotType    => "simple-filter",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $seen_read = 0;
	my $seen_write = 0;
	$reportDir =~ s/fiolatency/fio/;

	my @files = <$reportDir/$profile/fio_lat.*.log>;
	foreach my $file (@files) {
		my $nr_samples = 0;
		my $time;
		my $lat;
		my $dir;
		my $size;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			($time, $lat, $dir, $size) = split(/, /, $_);
			if ($dir == 0) {
				$dir = "read";
				$seen_read = 1;
			} elsif ($dir == 1) {
				$dir = "write";
				$seen_write = 1;
			} else {
				next;
			}
			$nr_samples++;
			push @{$self->{_ResultData}}, [ "latency-$dir", $nr_samples, $lat ];
		}
		close INPUT;
	}

	my @ops;

	if ($seen_read == 1) {
		push @ops, "latency-read";
	}
	if ($seen_write == 1) {
		push @ops, "latency-write";
	}

	$self->{_Operations} = \@ops;
}

1;
