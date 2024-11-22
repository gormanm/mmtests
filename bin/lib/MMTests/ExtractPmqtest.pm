# ExtractPmqtest.pm
package MMTests::ExtractPmqtest;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPmqtest",
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

sub extractReport() {
	my ($self, $reportDir) = @_;

	open(INPUT, "$reportDir/pmqtest.log") || die("Failed to open data file\n");
	while (<INPUT>) {
		next if ($_ !~ /\#+([0-9]+) -> \#+([0-9]+), Min\s+([0-9]+), Cur\s+([0-9]+), Avg\s+([0-9]+), Max\s+([0-9]+)/);
		$self->addData("Min-$1->$2", 0, $3);
		$self->addData("Avg-$1->$2", 0, $5);
		$self->addData("Max-$1->$2", 0, $6);
	}
	close INPUT;
}

1;
