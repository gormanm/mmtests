# ExtractFiolatency
package MMTests::ExtractFiolatency;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "Fiolatency.pm",
		_DataType    => DataTypes::DATA_TIME_NSECONDS,
		_ResultData  => [],
		_PlotType    => "simple-filter",
		_PlotXaxis   => "Time (seconds)",
		_FieldLength => 16,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $seen_read = 0;
	my $seen_write = 0;
	$reportDir =~ s/fiolatency/fio/;

	my @resultData;

	my @files = <$reportDir/$profile/fio_lat.*.log*>;
	foreach my $file (@files) {
		my $nr_samples = 0;
		my $time;
		my $lat;
		my $dir;
		my $size;

		if ($file =~ /.*\.gz$/) {
			open(INPUT, "gunzip -c $file|") || die("Failed to open $file.gz\n");
		} else {
			open(INPUT, $file) || die("Failed to open $file\n");
		}
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
			$time /= 1000;
			push @resultData, [ "latency-$dir", $time, $lat ];
		}
		close INPUT;
	}

	@resultData = sort { $a->[1] <=> $b->[1] } @resultData;
	$self->{_ResultData} = \@resultData;

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
