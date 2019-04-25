# SummariseSingleops.pm
package MMTests::SummariseSingleops;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "SummariseSingleops",
	};
	bless $self, $class;
	return $self;
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

	$self->{_FieldFormat} = [ "%-${fieldLength}s", "", "%${fieldLength}.2f" ];
	$self->{_FieldHeaders} = [ "Type", $self->{_Opname} ? $self->{_Opname} : "Ops" ];

	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ $self->{_Opname} ? $self->{_Opname} : "Ops"  ];
	$self->{_SummariseColumn} = 2;

	if ($self->{_DataType} == DataTypes::DATA_TIME_SECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_NSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_MSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_USECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_CYCLES ||
	    $self->{_DataType} == DataTypes::DATA_BAD_ACTIONS) {
		$self->{_CompareOp} = "pndiff";
	}
	if ($self->{_DataType} == DataTypes::DATA_ACTIONS ||
	    $self->{_DataType} == DataTypes::DATA_ACTIONS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_ACTIONS_PER_MINUTE ||
	    $self->{_DataType} == DataTypes::DATA_OPS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_OPS_PER_MINUTE ||
	    $self->{_DataType} == DataTypes::DATA_KBYTES_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_MBYTES_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_MBITS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_TRANS_PER_SECOND ||
	    $self->{_DataType} == DataTypes::DATA_TRANS_PER_MINUTE ||
	    $self->{_DataType} == DataTypes::DATA_SUCCESS_PERCENT  ||
	    $self->{_DataType} == DataTypes::DATA_RATIO_SPEEDUP) {
		$self->{_CompareOp} = "pdiff";
	}

	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my %data = %{$self->dataByOperation()};
	my @ops = sort { $a cmp $b } keys %data;

	$self->{_Operations} = \@ops;
	$self->{_SummaryData} = {};
	foreach my $op (@ops) {
		# There should be only one entry in the array...
		foreach my $row (@{$data{$op}}) {
			$self->{_SummaryData}->{$op} = [ @{$row}[1] ];
		}
	}
	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my %data = %{$self->dataByOperation()};
	my @ops = sort { $a cmp $b } keys %data;
	my @ratioops;

	if (!defined $self->{_SingleType}) {
		print "Unsupported\n";
		return 1;
	}

	$self->{_Operations} = \@ops;
	@ratioops = $self->ratioSummaryOps($subHeading);

	$self->{_SummaryHeaders} = [ "Ratio" ];
	$self->{_Operations} = \@ops;

	$self->{_SummaryData} = {};
	foreach my $op (@ratioops) {
		# There should be only one entry in the array...
		foreach my $row (@{$data{$op}}) {
			$self->{_SummaryData}->{$op} = [ @{$row}[1] ];
		}
	}

	return 1;
}

1;
