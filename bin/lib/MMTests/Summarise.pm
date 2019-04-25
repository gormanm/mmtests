# Summarise.pm
package MMTests::Summarise;
use MMTests::Extract;
use MMTests::DataTypes;
use MMTests::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "Summarise",
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
	} else {
		$self->{_Opname} = $opName;
	}
	if (defined $self->{_PlotType}) {
		$plotType = $self->{_PlotType};
	} else {
		$self->{_PlotType} = $plotType;
	}

	if ($self->{_DataType} == DataTypes::DATA_TIME_SECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_NSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_MSECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_USECONDS ||
	    $self->{_DataType} == DataTypes::DATA_TIME_CYCLES ||
	    $self->{_DataType} == DataTypes::DATA_BAD_ACTIONS) {
		$self->{_MeanName} = "Amean";
		$self->{_RatioPreferred} = "Lower";
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
	    $self->{_DataType} == DataTypes::DATA_SUCCESS_PERCENT) {
		$self->{_MeanName} = "Hmean";
		$self->{_RatioPreferred} = "Higher";
	}

	$self->SUPER::initialise($reportDir, $testName);
	$self->{_FieldLength} = 12 if ($self->{_FieldLength} == 0);
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Type", "Sample", $opName ];
	$self->{_SummaryLength} = $self->{_FieldLength} + 4 if !defined $self->{_SummaryLength};
	$self->{_SummariseColumn} = 2;
	$self->{_TestName} = $testName;
}

sub summaryOps() {
	my ($self, $subHeading) = @_;
	my @ops;

	foreach my $operation (@{$self->{_Operations}}) {
		if ($subHeading ne "" && !($operation =~ /^$subHeading.*/)) {
			next;
		}
		push @ops, $operation;
	}

	return @ops;
}

sub ratioSummaryOps() {
	my ($self, $subHeading) = @_;
	my @ratioops;
	my @ops;

	if (!defined($self->{_RatioOperations})) {
		@ratioops = @{$self->{_Operations}};
	} else {
		@ratioops = @{$self->{_RatioOperations}};
	}

	if ($subHeading eq "") {
		return @ratioops;
	}

	foreach my $operation (@ratioops) {
		if (!($operation =~ /^$subHeading.*/)) {
			next;
		}
		push @ops, $operation;
	}

	return @ops;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my %data = %{$self->dataByOperation()};
	my @_operations = @{$self->{_Operations}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	if ($subHeading eq "") {
		$subHeading = $self->{_DefaultPlot}
	}


	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($self->{_ExactSubheading} == 1) {
				if (defined $self->{_ExactPlottype}) {
					$self->{_PlotType} = $self->{_ExactPlottype};
				}
				if ($_operations[$index] eq "$subHeading") {
					$index++;
					next;
				}
			} elsif ($self->{_ClientSubheading} == 1) {
				if ($_operations[$index] =~ /.*-$subHeading$/) {
					$index++;
					next;
				}
			} else {
				if ($_operations[$index] =~ /^$subHeading.*/) {
					$index++;
					next;
				}
			}
			splice(@_operations, $index, 1);
		}
	}

	$self->sortResults();

	my $nr_headings = 0;
	foreach my $heading (@_operations) {
		my @index;
		my @units;
		my @row;
		my $samples = 0;

		foreach my $row (@{$data{$heading}}) {
			push @index, @{$row}[0];
			push @units, @{$row}[1];
			$samples++;
		}

		$nr_headings++;
		if ($self->{_PlotType} =~ /simple.*/) {
			my $fake_samples = 0;

			if ($self->{_PlotType} =~ /simple-samples/) {
				$fake_samples = 1;
			}

			for ($samples = 0; $samples <= $#index; $samples++) {
				my $stamp = $index[$samples] - $index[0];
				if ($fake_samples) {
					$stamp = $samples;
				}

				# Use %d for integers to avoid strangely looking graphs
				if (int $index[$samples] != $index[$samples]) {
					printf("%-${fieldLength}.3f %${fieldLength}.3f\n", $stamp, $units[$samples]);
				} else {
					printf("%-${fieldLength}d %${fieldLength}.3f\n", $stamp, $units[$samples]);
				}
			}
		} elsif ($self->{_PlotType} eq "candlesticks") {
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
			if ($self->{_ClientSubheading} == 1) {
				$heading =~ s/-.*//;
			} else {
				$heading =~ s/.*-//;
			}
			printf "%-${fieldLength}s ", $heading;
			$self->_printErrorBarData($fieldLength, @units);
		} elsif ($self->{_PlotType} =~ "histogram") {
			for ($samples = 0; $samples <= $#units; $samples++) {
				printf("%-${fieldLength}s %${fieldLength}.3f\n",
					$heading, $units[$samples]);
			}
		}
	}
}

1;
