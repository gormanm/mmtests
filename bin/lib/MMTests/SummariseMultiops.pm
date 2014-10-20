# SummariseMultiops.pm
package MMTests::SummariseMultiops;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "SummariseMultiops",
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $plotType = "candlesticks";
	my $opName = "Ops";
	if (defined $self->{_Opname}) {
		$opName = $self->{_Opname};
	}
	if (defined $self->{_PlotType}) {
		$plotType = $self->{_PlotType};
	}
	$self->{_Opname} = $opName;
	$self->{_PlotType} = $plotType;

	$self->{_RatioPreferred} = "Higher";
	$self->{_MeanOp} = "calc_harmmean";
	$self->{_MeanName} = "Hmean";

	if ($self->{_DataType} == MMTests::Extract::DATA_TIME_SECONDS ||
	    $self->{_DataType} == MMTests::Extract::DATA_TIME_NSECONDS ||
	    $self->{_DataType} == MMTests::Extract::DATA_TIME_MSECONDS ||
	    $self->{_DataType} == MMTests::Extract::DATA_TIME_USECONDS) {
		$self->{_MeanOp} = "calc_mean";
		$self->{_MeanName} = "Amean";
		$self->{_RatioPreferred} = "Lower";
	}

	$self->SUPER::initialise($reportDir, $testName);

	$self->{_FieldLength} = 12;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Type", "Sample", $self->{_Opname} ? $self->{_Opname} : "Ops" ];

	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Op", "Min", $self->{_MeanName}, "Stddev", "CoeffVar", "Max" ];
	$self->{_SummariseColumn} = 2;
	$self->{_TestName} = $testName;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @_operations = @{$self->{_Operations}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($_operations[$index] =~ /^$subHeading.*/) {
				$index++;
				next;
			}
			splice(@_operations, $index, 1);
		}
	}

	my $nr_headings = 0;
	foreach my $heading (@_operations) {
		my @units;
		my @row;
		my $samples = 0;
		$heading =~ s/\s//g;
		foreach my $row (@data) {
			@{$row}[0] =~ s/\s+//g;
			if (@{$row}[0] eq $heading) {
				push @units, @{$row}[2];
				$samples++;
			}
		}

		$nr_headings++;
		if ($self->{_PlotType} eq "candlesticks") {
			printf "%-${fieldLength}s ", $heading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "operation-candlesticks") {
			printf "%d %-${fieldLength}s ", $nr_headings, $heading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-candlesticks") {
			$heading =~ s/.*-//;
			printf "%-${fieldLength}s ", $heading;
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "single-candlesticks") {
			$self->_printCandlePlotData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-errorbars") {
			$heading =~ s/.*-//;
			printf "%-${fieldLength}s ", $heading;
			$self->_printErrorBarData($fieldLength, @units);
		} elsif ($self->{_PlotType} eq "client-errorlines") {
			$heading =~ s/.*-//;
			printf "%-${fieldLength}s ", $heading;
			$self->_printErrorBarData($fieldLength, @units);
		}
	}
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};

	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($_operations[$index] =~ /^$subHeading.*/) {
				$index++;
				next;
			}
			splice(@_operations, $index, 1);
		}
	}

	foreach my $operation (@_operations) {
		my @units;
		my @row;
		my $samples = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
				$samples++;
			}
		}
		push @row, $operation;
		foreach my $funcName ("calc_min", $self->{_MeanOp}, "calc_stddev", "calc_coeffvar", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;

	}

	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};

	$self->{_SummaryHeaders} = [ "Op", "Ratio" ];

	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($_operations[$index] =~ /^$subHeading.*/) {
				$index++;
				next;
			}
			splice(@_operations, $index, 1);
		}
	}

	foreach my $operation (@_operations) {
		my @units;
		my @row;
		my $samples = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
				$samples++;
			}
		}
		push @row, $operation;
		foreach my $funcName ($self->{_MeanOp}) {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;

	}

	return 1;
}

1;
