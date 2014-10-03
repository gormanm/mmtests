# ExtractSeeker.pm
package MMTests::ExtractSeeker;
use MMTests::Extract;
use VMR::Report;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSeeker",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => [],
		_SummariseColumn => 2,
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "WalltimeVariable,TestName,Seeks,candlesticks\n";
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

	my $file = "$reportDir/noprofile/seeker.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		if ($_ =~ /^mark: ([0-9]*).*/) {
			push @{$self->{_ResultData}}, ["Seeks", ++$iteration, $1];
		}
	}
	close INPUT;
}
1;
