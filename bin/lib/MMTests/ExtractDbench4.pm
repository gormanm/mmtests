# ExtractDbench4.pm
package MMTests::ExtractDbench4;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractDbench4",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	my $heading = $self->{_SummariseColumn};
	print "Throughput,Clients,$heading,candlestick";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/dbench-*.log>;
	if ($files[0] eq "") {
		@files = <$reportDir/noprofile/tbench-*.log>;
	}
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
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f" ];
	$self->{_FieldHeaders} = [ "Client", "Time", "MB/sec", "Latency" ];
	$self->{_SummaryHeaders} = [ "Client", "Min", "Mean", "TrueMean", "Stddev", "Max" ];
	$self->{_ExtraHeaders} = [ "Operation", "AvgLatency", "MaxLatency" ];
	$self->{_ExtraLength} = $self->{_FieldLength};
	$self->{_ExtraFormat} = [ "%-{$fieldLength}d", "%-${fieldLength}s", "%$fieldLength.3f" , "%${fieldLength}.3f" ];
}

sub _setSummaryColumn() {
	my ($self, $subHeading) = @_;
	if ($subHeading eq "MB/sec") {
		$self->{_SummariseColumn} = 1;
	} elsif ($subHeading eq "Latency") {
		$self->{_SummariseColumn} = 2;
	} else {
		die("Unrecognised summarise header '$subHeading' for dbench4");
	}
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	$self->_setSummaryColumn($subHeading);

	my ($self, $reportDir) = @_;
	my @data = @{$self->{_ResultData}};
	my @clients = @{$self->{_Clients}};
	my $fieldLength = $self->{_FieldLength};
	my $column = $self->{_SummariseColumn};

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
	$self->_setSummaryColumn($subHeading);

	my ($self, $reportDir) = @_;
	my @data = @{$self->{_ResultData}};
	my @clients = @{$self->{_Clients}};
	my $fieldLength = $self->{_FieldLength};
	my $column = $self->{_SummariseColumn};

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

sub printExtra() {
	my ($self, $reportDir) = @_;
	my @clients = @{$self->{_Clients}};

	$self->_printClientExtra($reportDir, @clients);
}

sub printReport() {
	my ($self, $reportDir) = @_;
	my @clients = @{$self->{_Clients}};

	$self->_printClientReport($reportDir, @clients);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $readingOperations = 0;
	my @clients = @{$self->{_Clients}};
	my %dbench_ops = ("NTCreateX"	=> 1, "Close"	=> 1, "Rename"	=> 1,
			  "Unlink"	=> 1, "Deltree"	=> 1, "Mkdir"	=> 1,
			  "Qpathinfo"	=> 1, "WriteX"	=> 1, "ReadX"	=> 1,
			  "Qfileinfo"	=> 1, "Qfsinfo"	=> 1, "Flush"	=> 1,
			  "Sfileinfo"	=> 1, "LockX"	=> 1, "UnlockX"	=> 1,
			  "Find"	=> 1);

	foreach my $client (@clients) {
		my $file;
		$file = "$reportDir/noprofile/dbench-$client.log";
		if (! -e $file) {
			$file = "$reportDir/noprofile/tbench-$client.log";
		}
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);
				push @{$self->{_ResultData}[$client]}, [ $elements[6], $elements[3], $elements[9] ];
				next;
			}

			if ($line =~ /Operation/) {
				$readingOperations = 1;
				next;
			}

			if ($readingOperations == 1) {
				my @elements = split(/\s+/, $line);
				if ($dbench_ops{$elements[1]} == 1) {
					push @{$self->{_ExtraData}[$client]},
						[ $elements[1], $elements[3], $elements[4] ];
				}
			}
		}
		close INPUT;
	}
}

1;
