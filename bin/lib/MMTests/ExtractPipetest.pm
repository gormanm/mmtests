# ExtractPipetest.pm
package MMTests::ExtractPipetest;
use MMTests::Extract;
use VMR::Report;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPipetest",
		_DataType    => MMTests::Extract::DATA_WALLTIME_VARIABLE,
		_ResultData  => [],
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "WalltimeVariable,TestName,Time,candlesticks\n";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}d", "%$fieldLength.2f" ];
	$self->{_FieldHeaders}[0] = "PipePairs";
	$self->{_TestName} = $testName;
}

sub printPlot() {
	my ($self, $subheading) = @_;

	$self->_printCandlePlot($self->{_FieldLength}, 1);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/noprofile/pipetest.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		my @elements = split(/\s/);
		push @{$self->{_ResultData}}, ["Time", ++$iteration, $elements[0]];
	}
	close INPUT;
}
1;
