# ExtractCyclictest.pm
package MMTests::ExtractCyclictest;
use MMTests::SummariseMultiops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseMultiops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractCyclictest",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $iteration = 0;
	foreach my $file (<$reportDir/noprofile/cyclictest-*.log>) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if ($_ !~ /^T.*Avg:\s+([0-9]+).*Max:\s+([0-9]+)/);
			$iteration++;
			push @{$self->{_ResultData}}, [ "LatAvg", $iteration, $1];
			push @{$self->{_ResultData}}, [ "LatMax", $iteration, $2];
		}
		close INPUT;
	}

	$self->{_Operations} = [ "LatAvg", "LatMax" ];
}
