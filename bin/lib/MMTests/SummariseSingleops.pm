# SummariseSingleops.pm
package MMTests::SummariseSingleops;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "SummariseSingleops",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $opName = "Ops";
	if (defined $self->{_Opname}) {
		$opName = $self->{_Opname};
	}

	$self->SUPER::initialise($reportDir, $testName);

	$self->{_FieldLength} = 12;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Type", "Sample", $self->{_Opname} ? $self->{_Opname} : "Ops" ];

	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Type", $self->{_Opname} ? $self->{_Opname} : "Ops"  ];
	$self->{_SummariseColumn} = 2;
	$self->{_TestName} = $testName;
}

sub printDataType() {
	print "Operations/sec";
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

1;
