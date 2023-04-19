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

	my $input = $self->SUPER::open_log("$reportDir/cyclictest.log");
	while (<$input>) {
		next if ($_ !~ /\s+([0-9]+):\s+([0-9]+):\s+([0-9]+)/);
		$self->addData("sample-anycpu", $2, $3);
	}
	close $input;
}

1;
