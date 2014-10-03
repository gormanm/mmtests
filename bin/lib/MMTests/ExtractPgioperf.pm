# ExtractPgioperf.pm
package MMTests::ExtractPgioperf;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPgioperf",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "Operations/sec,TestName,Latency,candlesticks";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 16;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Op", "Sample" ];

	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Op", "Min", "Mean", "Stddev", "Max" ];
	$self->{_SummariseColumn} = 2;
	$self->{_TestName} = $testName;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	if ($subHeading eq "") {
		$subHeading = "SeqOut Block";
	}
	$subHeading =~ s/\s+//g;

	my @units;
	my @row;
	my $samples = 0;
	foreach my $row (@data) {
		@{$row}[0] =~ s/\s+//g;
		if (@{$row}[0] eq $subHeading) {
			push @units, @{$row}[2];
			$samples++;
		}
	}
	$self->_printCandlePlotData($fieldLength, @units);
}


sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};

	if ($subHeading ne "") {
		$#_operations = 0;
		$_operations[0] = $subHeading;
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
		foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;

	}

	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $recent = 0;

	open(INPUT, "$reportDir/noprofile/pgioperf.log") || die("Failed to open $reportDir/noprofile/pgioperf.log");
	my %samples;
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		if ($line =~ /([a-z]+)\[[0-9]+\]: avg: ([0-9.]+) msec; max: ([0-9.]+) msec/) {

			my $op = $1;
			my $avg = $2;
			my $max = $3;
			push @{$self->{_ResultData}}, [ $op, ++$samples{$op}, $max ];
		}
	}
	my @ops = keys %samples;
	$self->{_Operations} = \@ops;
	close INPUT;
}

1;
