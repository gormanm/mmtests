# ExtractCyclictest.pm
package MMTests::ExtractCyclictest;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractCyclictest",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple",
		_PlotStripSubheading => 1,
		_SingleType  => 1,
		_PlotXaxis   => "CPU",
		_Opname      => "Lat",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $input = $self->SUPER::open_log("$reportDir/cyclictest.log");
	while (<$input>) {
		next if ($_ !~ /^T: ([0-9+]) .*Avg:\s+([0-9]+).*Max:\s+([0-9]+)/);
		$self->addData("Avg-$1", 0, $2);
		$self->addData("Max-$1", 0, $3);
	}
	close $input;
}

1;
