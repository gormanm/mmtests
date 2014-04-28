# ExtractDbench3.pm
package MMTests::ExtractDbench3;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractDbench3",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}


sub printDataType() {
	my ($self) = @_;
	print "Throughput,Clients,MB/sec";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/dbench-*.log>;
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
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Client", "Time", "MB/sec" ];
	$self->{_SummaryHeaders} = [ "Client", "Min", "Mean", "TrimMean", "Stddev", "Max" ];
}

sub printPlot() {
	my ($self, $subHeading) = @_;
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

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @clients = @{$self->{_Clients}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	foreach my $client (@clients) {
		my @units;
		my @row;
		foreach my $row (@{$data[$client]}) {
			push @units, @{$row}[$column];
		}
		push @row, $client;
		foreach my $funcName ("calc_min", "calc_mean", "calc_5trimmed_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;
	}
	return 1;
}

sub printReport() {
	my ($self, $reportDir) = @_;
	my @clients = @{$self->{_Clients}};

	$self->_printClientReport($reportDir, @clients);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my @clients = @{$self->{_Clients}};

	foreach my $client (@clients) {
		my $file = "$reportDir/noprofile/dbench-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);
				push @{$self->{_ResultData}[$client]}, [ $elements[6], $elements[3], $elements[9] ];
				next;
			}
		}
		close INPUT;
	}
}

1;
