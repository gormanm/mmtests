# ExtractCyclictest.pm
package MMTests::ExtractCyclictestfine;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractCyclictestfine",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple-points",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	open(INPUT, "unxz --stdout $reportDir/cyclictest.log.xz|") || die("Failed to open data file\n");
	while (<INPUT>) {
		next if ($_ !~ /\s+([0-9]+):\s+([0-9]+):\s+([0-9]+)/);
		$self->addData("sample-anycpu", $2, $3);
	}
	close INPUT;
}

1;
