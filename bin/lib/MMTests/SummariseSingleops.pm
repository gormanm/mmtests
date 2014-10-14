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
	};
	bless $self, $class;
	return $self;
}

sub printPlot() {
	my ($self, $subHeading) = @_;

	if ($subHeading eq "") {
		$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
	} else {
		my @filteredData;
		foreach my $row (@{$self->{_ResultData}}) {
			if (@{$row}[0] =~ /^$subHeading.*/) {
				push @filteredData, $row;
			}
		}
		$self->{_PrintHandler}->printRow(\@filteredData, $self->{_FieldLength}, $self->{_FieldFormat});
	}
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $opName = "Ops";
	my $fieldLength = 12;
	if (defined $self->{_FieldLength}) {
		$fieldLength = $self->{_FieldLength};
	}
	if (defined $self->{_Opname}) {
		$opName = $self->{_Opname};
	} else {
		$self->{_Opname} = "Ops";
	}

	$self->SUPER::initialise($reportDir, $testName);

	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Type", "Sample", $self->{_Opname} ? $self->{_Opname} : "Ops" ];

	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Type", $self->{_Opname} ? $self->{_Opname} : "Ops"  ];
	$self->{_SummariseColumn} = 2;
	$self->{_TestName} = $testName;
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
