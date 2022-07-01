# ExtractHpcc.pm
package MMTests::ExtractHpccscore;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractHpccscore",
		_DataType    => DataTypes::DATA_OPS_PER_SECOND,
		_Precision   => 4,
		_Operations  => [ "HPL_Tflops", "PTRANS_GBs",
			"MPIRandomAccess_GUPs", "MPIFFT_Gflops",
			"StarSTREAM_Triad", "StarDGEMM_Gflops",
			"RandomlyOrderedRingBandwidth_GBytes" ],
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/hpccoutf-*.txt>) {
		$iteration++;

		open (INPUT, $file) || die("Failed to open $file");
		while (!eof(INPUT)) {
			my $line = <INPUT>;

			foreach my $metric (@{$self->{_Operations}}) {
				if ($line =~ /^$metric=(.*)/) {
					$self->addData("$metric", $iteration, $1);
				}
			}
		}
		close (INPUT);
	}
}

1;
