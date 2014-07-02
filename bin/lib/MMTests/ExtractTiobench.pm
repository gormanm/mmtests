# ExtractTiobench.pm
package MMTests::ExtractTiobench;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTiobench",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => [],
		_FieldLength => 16,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
        my ($self) = @_;
        print "Throughput,Clients,MB/sec,candlestick";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/tiobench-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;
	$self->{_Clients} = \@clients;

	$self->SUPER::initialise();

	my $fieldLength = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}d", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Operation", "Iteration", "MB/sec" , "CPU", "AvgLatency", "MaxLatency", "%gt2sec", "%gt10sec" ];
	$self->{_SummaryHeaders} = [ "Operation", "Min", "Mean", "Stddev", "Max" ];
}

sub setSummaryLength() {
	my ($self, $subHeading) = @_;

	if ($subHeading eq "") {
		$subHeading = "MB/sec";
	}

	my $fieldLength = length("RandWrite") + length($subHeading) + 4;
        $self->{_FieldLength} = $fieldLength;
        $self->{_SummaryLength} = $fieldLength;
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}d", "%$fieldLength.2f" ];
}

sub _setSummaryColumn() {
	my ($self, $subHeading) = @_;
	my @headers = @{$self->{_FieldHeaders}};
	my $index;
	if ($subHeading eq "") {
		$subHeading = "MB/sec";
	}

	for ($index = 2; $index < $#headers; $index++) {
		if ($headers[$index] eq $subHeading) {
			$self->{_SummariseColumn} = $index;
		}
	}
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my $fieldLength = $self->{_FieldLength};
	my @ops;

	my ($opName, $heading, $client) = split(/-/, $subHeading);
	if ($opName eq "" || $heading eq "" || $client eq "") {
		die("sub-heading format it \$operation-\$heading-\$client e.g. RandRead-MB/sec-1\n");
	}

	$self->_setSummaryColumn($heading);
	my $column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};
	foreach my $row (@{$self->{_ResultData}}) {
		if (@{$row}[0] =~ /$opName-$client$/) {
			push @ops, @{$row}[$column];
		}
	}

	 $self->_printCandlePlotData($fieldLength, @ops);
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my $column = 0;
	my @clients = @{$self->{_Clients}};

	$self->_setSummaryColumn($subHeading);
	$column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};
	if ($subHeading eq "") {
		$subHeading = "MB/sec";
	}

	push @{$self->{_SummaryData}}, [ "PotentialReadSpeed", $self->{_MaxReadSpeed}, $self->{_MaxReadSpeed}, 0, $self->{_MaxReadSpeed} ];

	# Yeah, not the most efficient. Not big enough structure to care
	foreach my $opName ("SeqRead", "RandRead", "SeqWrite", "RandWrite") {
		foreach my $client (@clients) {
			my @ops;
			my @row;
			push @row, "$opName-$subHeading-$client";
			foreach my $row (@{$self->{_ResultData}}) {
				if (@{$row}[0] =~ /$opName-$client$/) {
					push @ops, @{$row}[$column];
				}
			}
			foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max") {
				no strict "refs";
				push @row, &$funcName(@ops)
			}
			push @{$self->{_SummaryData}}, \@row;
		}
	}

	return 1;
}

sub printSummary() {
	my ($self, $subHeading) = @_;

	$self->_setSummaryColumn($subHeading);
	$self->SUPER::printSummary($subHeading);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @clients = @{$self->{_Clients}};
	my $op;
	my $reading = 0;
	my $max_read = -1;

	if (open(INPUT, "$reportDir/noprofile/disk-read.speed")) {
		$max_read = <INPUT>;
		close(INPUT);
	}
	$self->{_MaxReadSpeed} = $max_read;


	foreach my $client (@clients) {
		my @files = <$reportDir/noprofile/tiobench-$client-*.log>;
		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;

				if ($reading) {
					my @elements = split(/\s+/, $_);
					if ($elements[4] =~ /#/) {
						$elements[4] = -1;
					}
					push @{$self->{_ResultData}}, [ "$op-$client", $iteration, $elements[4], $elements[5], $elements[6], $elements[7], $elements[8], $elements[9] ];
					$reading = 0;
					next;
				}

				chomp($line);
				if ($line eq "Sequential Reads") {
					$reading = 1;
					$op = "SeqRead";
					next;
				}
				if ($line eq "Random Reads") {
					$reading = 1;
					$op = "RandRead";
					next;
				}
				if ($line eq "Sequential Writes") {
					$reading = 1;
					$op = "SeqWrite";
					next;
				}
				if ($line eq "Random Writes") {
					$reading = 1;
					$op = "RandWrite";
					next;
				}
			}
			close INPUT;
		}
	}
}

1;
