# SummariseVariabletime.pm
package MMTests::SummariseVariabletime;
use MMTests::Extract;
use MMTests::Summarise;
use MMTests::Stat;
our @ISA = qw(MMTests::Summarise);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_SummaryStats} = [ "min", "percentile-25", "percentile-50",
		"percentile-75", "percentile-1", "percentile-5",
		"percentile-10", "percentile-90",  "percentile-95",
		"percentile-99", "max", "_mean", "stddev", "coeffvar",
		"_mean-99", "_mean-95", "_mean-90", "_mean-75", "_mean-50",
		"_mean-25" ];
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->summaryOps($subHeading);
	my %data = %{$self->dataByOperation()};

	my $meanOp = $self->getMeanFunc;
	my $selectOp = $self->getSelectionFunc();
	my %summary;

	foreach my $operation (@_operations) {
		no strict  "refs";

		my @units;
		my @row;
		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}

		my $quartilesRef = calc_quartiles(\@units);
		my @quartiles = @{$quartilesRef};
		push @row, calc_min(\@units);
		push @row, $quartiles[25];
		push @row, $quartiles[50];
		push @row, $quartiles[75];
		push @row, $quartiles[1];
		push @row, $quartiles[5];
		push @row, $quartiles[10];
		push @row, $quartiles[90];
		push @row, $quartiles[95];
		push @row, $quartiles[99];
		push @row, calc_max(\@units);
		push @row, &$meanOp(\@units);
		push @row, calc_stddev(\@units);
		push @row, calc_coeffvar(\@units);
		push @row, &$meanOp(&$selectOp(99, \@units));
		push @row, &$meanOp(&$selectOp(95, \@units));
		push @row, &$meanOp(&$selectOp(90, \@units));
		push @row, &$meanOp(&$selectOp(75, \@units));
		push @row, &$meanOp(&$selectOp(50, \@units));
		push @row, &$meanOp(&$selectOp(25, \@units));

		$summary{$operation} = \@row;
	}
	$self->{_SummaryData} = \%summary;

	return 1;
}

sub extractRatioSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = $self->ratioSummaryOps($subHeading);
	my %data = %{$self->dataByOperation()};

	$self->{_SummaryHeaders} = [ "Ratio" ];
	my %summary;

	foreach my $operation (@_operations) {

		my @units;
		my @row;

		foreach my $row (@{$data{$operation}}) {
			push @units, @{$row}[1];
		}
		my $quartilesRef = calc_quartiles(\@units);
		my @quartiles = @{$quartilesRef};
		$summary{$operation} = [$quartiles[95]];
	}
	$self->{_SummaryData} = \%summary;

	return 1;
}

1;
