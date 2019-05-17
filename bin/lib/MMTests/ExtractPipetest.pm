# ExtractPipetest.pm
package MMTests::ExtractPipetest;
use MMTests::SummariseVariabletime;
use Math::Round;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPipetest",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/pipetest.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		my @elements = split(/\s/);
		my $t = nearest(.5, $elements[0]);
		$self->addData("Time", ++$iteration, $t);
	}

	$self->{_Operations} = [ "Time" ];
	close INPUT;
}
1;
