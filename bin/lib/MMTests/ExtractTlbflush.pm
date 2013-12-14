# ExtractTlbflush.pm
package MMTests::ExtractTlbflush;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTlbflush",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	print "Throughput,Clients,Records/sec";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/tlbflush-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;
	$self->{_Clients} = \@clients;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%$fieldLength.4f",
				  "%$fieldLength.4f",  "%$fieldLength.4f", "%$fieldLength.4f" ];
	$self->{_FieldHeaders} = [ "Client", "Iteration", "Records/sec", "User", "Sys" ];
	$self->{_SummaryHeaders} = [ "Client", "Min", "Mean", "TrueMean", "Stddev", "Max" ];
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my ($self, $reportDir) = @_;
	my @data = @{$self->{_ResultData}};
	my @clients = @{$self->{_Clients}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	foreach my $client (@clients) {
		my @units;
		foreach my $row (@{$data[$client]}) {
			push @units, @{$row}[$column];
		}
		printf("%-${fieldLength}d", $client);
		$self->_printCandlePlotData($fieldLength, @units);
	}
}

sub _setSummaryColumn() {
	my ($self, $subHeading) = @_;
	my @headers = @{$self->{_FieldHeaders}};
	my $index;
	if ($subHeading eq "") {
		$subHeading = "Records/sec";
	}

	for ($index = 2; $index < $#headers; $index++) {
		if ($headers[$index] eq $subHeading) {
			$self->{_SummariseColumn} = $index;
		}
	}

	return $subHeading;
}

sub extractSummary() {
	my ($self, $subHeading) = @_;

	my ($self, $reportDir) = @_;
	my @data = @{$self->{_ResultData}};
	my @clients = @{$self->{_Clients}};
	my $fieldLength = $self->{_FieldLength};
	my $column;

	$subHeading = $self->_setSummaryColumn($subHeading);
	$column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};

	# Adjust column to take into account client is structured as array
	$column--;

	foreach my $client (@clients) {
		my @units;
		my @row;
		foreach my $row (@{$data[$client]}) {
			push @units, @{$row}[$column];
		}
		push @row, $client;
		foreach my $funcName ("calc_min", "calc_mean", "calc_true_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;
	}
	return 1;
}

sub printSummary() {
	my ($self, $subHeading) = @_;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.2f" ];
	$self->SUPER::printSummary($subHeading);
}

sub printReport() {
	my ($self, $reportDir) = @_;
	my @clients = @{$self->{_Clients}};

	$self->_printClientReport($reportDir, @clients);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @clients = @{$self->{_Clients}};

	foreach my $client (@clients) {
		my $iteration = 1;

		my $file = "$reportDir/noprofile/tlbflush-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		my ($user, $sys, $records);
		while (<INPUT>) {
			if ($_ =~ /.*, cost ([0-9]*)ns.*/) {
				push @{$self->{_ResultData}[$client]}, [ $iteration, $1 ];
				$iteration++;
			}
		}
		close INPUT;
	}
}

1;
