# ExtractMutilate.pm
package MMTests::ExtractMutilate;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractMutilate",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	print "Operations,Clients,Ops/sec";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/mutilate-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;
	$self->{_Clients} = \@clients;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Client", "Iteration", "Ops/sec" ];
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
		$self->_printSimplePlotData($fieldLength, @units);
	}
}

sub extractSummary() {
	my ($self, $subHeading) = @_;

	my ($self, $reportDir) = @_;
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
		foreach my $funcName ("calc_min", "calc_mean", "calc_true_mean", "calc_stddev", "calc_max") {
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
	my @clients = @{$self->{_Clients}};

	foreach my $client (@clients) {
		my $iteration = 1;

		my @files = <$reportDir/noprofile/mutilate-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if ($_ !~ /^Total QPS/);
				my @elements = split(/\s+/, $_);
				push @{$self->{_ResultData}[$client]}, [ $iteration, $elements[3] ];
			}
			close INPUT;
			$iteration++;
		}
	}
}

1;
