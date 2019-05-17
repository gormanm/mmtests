# ExtractTimeexit.pm
package MMTests::ExtractTimeexit;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTimeexit",
		_DataType    => DataTypes::DATA_TIME_MSECONDS,
		_Precision   => 6,
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $file = "$reportDir/timeexit.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $nr_samples = 0;
	while (<INPUT>) {
		my @elements = split(/\s+/);
		$self->addData("procs-$elements[0]", ++$nr_samples, $elements[1] * 1000);
	}
	close INPUT;
}
1;
