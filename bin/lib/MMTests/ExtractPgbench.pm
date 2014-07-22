# ExtractPgbench.pm
package MMTests::ExtractPgbench;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPgbench",
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

	my @files = <$reportDir/noprofile/default/pgbench-raw-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;
	$self->{_Clients} = \@clients;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_TestName} = $testName;
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

sub extractSummary() {
	my ($self, $subHeading) = @_;

	my ($self, $reportDir) = @_;
	my @clients = @{$self->{_Clients}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	if ($subHeading eq "LoadTime") {
		my @data = @{$self->{_LoadTimeData}};

		$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%$fieldLength.2f" ];
		$self->{_FieldHeaders} = [ "Client", "Time" ];
		$self->{_SummaryHeaders} = [ "Client", "Min", "Mean", "TrimMean", "Stddev", "Max" ];
		$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%$fieldLength.2f" ];

		my @units;
		my @row;
		foreach my $row (@{$data[0]}) {
			push @units, @{$row}[1];
		}
		push @row, 1;
		foreach my $funcName ("calc_min", "calc_mean", "calc_5trimmed_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;
		return 1;
	}

	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%$fieldLength.2f" ];
	$self->{_SummaryHeaders} = [ "Client", "Min", "Mean", "TrimMean", "Stddev", "Max" ];

	if ($subHeading eq "TransTime") {
		my @data = @{$self->{_ResultTimeData}};
		$self->{_FieldHeaders} = [ "Client", "Iteration", "Time" ];
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

	my @data = @{$self->{_ResultData}};
	$self->{_FieldHeaders} = [ "Client", "Iteration", "Transactions/sec" ];
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
	my ($tm, $tput, $latency);
	my @clients = @{$self->{_Clients}};
	my $iteration;

	# Extract load times if available
	$iteration = 0;
	foreach my $client (@clients) {
		if (open (INPUT, "$reportDir/noprofile/default/load-$client.time")) {
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				push @{$self->{_LoadTimeData}[0]}, [ $iteration, $self->_time_to_elapsed($_) ];
			}
			close INPUT;
		}
	}

	# Extract per-client transaction information
	foreach my $client (@clients) {
		$iteration = 0;

		my @files = <$reportDir/noprofile/default/pgbench-raw-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /^tps/ && $_ =~ /including/) {
					my @elements = split(/\s+/, $_);
					push @{$self->{_ResultData}[$client]}, [ $iteration, $elements[2] ];
					$iteration++;
				}
			}
			close INPUT;
		}
	}

	# Extract per-client timing information
	my @clients = @{$self->{_Clients}};
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/noprofile/default/time-$client.*>;
		foreach my $file (@files) {


			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				push @{$self->{_ResultTimeData}[$client]}, [ $iteration, $self->_time_to_elapsed($_) ];
			}
			close(INPUT);
		}
	}
}

1;
