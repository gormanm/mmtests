# ExtractSparsetruncate.pm
package MMTests::ExtractSparsetruncate;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSparsetruncate",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple",
		_PlotXaxis   => "File",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $file = "$reportDir/truncate.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		my @elements = split(/\s/);
		$self->addData("Time", ++$iteration, $elements[0]);
	}
	close INPUT;
}
1;
