# ExtractTimeexit.pm
package MMTests::ExtractTimeexit;
use MMTests::Extract;
use VMR::Report;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTimeexit",
		_DataType    => MMTests::Extract::DATA_WALLTIME_VARIABLE,
		_ResultData  => [],
		_Precision   => 6,
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
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.6f", "%$fieldLength.6f", "%$fieldLength.6f", "%$fieldLength.6f", "%$fieldLength.6f" ];
	$self->{_FieldHeaders} = [ "Instances", "Iteration", "Time" ];
	$self->{_TestName} = $testName;
}

sub printPlot() {
	my ($self, $subheading) = @_;

	$self->_printCandlePlot($self->{_FieldLength}, 1);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/noprofile/timeexit.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements = split(/\s+/);
		push @{$self->{_ResultData}}, [$elements[0], 1, $elements[1]];
	}
	close INPUT;
}
1;
