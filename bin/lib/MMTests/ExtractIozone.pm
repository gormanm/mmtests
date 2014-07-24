# ExtractIozone.pm
package MMTests::ExtractIozone;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractIozone",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => [],
		_FieldLength => 16,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
        my ($self) = @_;
        print "Throughput,Testname,KB/sec,candlestick";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}d", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Operation", "Iteration", "KB/sec" ];
	$self->{_SummaryHeaders} = [ "Operation", "Min", "Mean", "Stddev", "Max" ];
}

sub setSummaryLength() {
	my ($self, $subHeading) = @_;

	if ($subHeading eq "") {
		$subHeading = "KB/sec";
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
		$subHeading = "KB/sec";
	}

	for ($index = 2; $index <= $#headers; $index++) {
		if ($headers[$index] eq $subHeading) {
			$self->{_SummariseColumn} = $index;
		}
	}
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my $fieldLength = $self->{_FieldLength};
	my @ops;

	my ($opName, $heading, $size, $blksize) = split(/-/, $subHeading);
	if ($opName eq "" || $heading eq "" || $size eq "" || $blksize eq "") {
		die("sub-heading format it \$operation-\$heading-\$size-\$blksize e.g. RandRead-KB/sec-1048576-4096\n");
	}

	$self->_setSummaryColumn($heading);
	my $column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};
	foreach my $row (@{$self->{_ResultData}}) {
		if (@{$row}[0] eq "$opName-$size-$blksize") {
			push @ops, @{$row}[$column];
		}
	}

	$self->_printCandlePlotData($fieldLength, @ops);
}

my %loadindex = (
	"SeqWrite"	=> 3,
	"Rewrite"	=> 4,
	"SeqRead"	=> 5,
	"Reread"	=> 6,
	"RandRead"	=> 7,
	"RandWrite"	=> 8,
	"BackRead"	=> 9
);

sub testcompare() {
	my ($opa, $sizea, $blksizea) = split /-/, @{$a}[0];
	my ($opb, $sizeb, $blksizeb) = split /-/, @{$b}[0];
	if ($opa ne $opb) {
		return $loadindex{$opa} <=> $loadindex{$opb};
	}
	if ($sizea != $sizeb) {
		return $sizea <=> $sizeb;
	}
	return $blksizea <=> $blksizeb;
}

sub _calcStats() {
	my ($self, $prevop, $subHeading, $ops) = @_;
	my @row;

	push @row, "$prevop-$subHeading";
	foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max") {
		no strict "refs";
		push @row, &$funcName(@{$ops})
	}

	push @{$self->{_SummaryData}}, \@row;
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my $column = 0;
	my @ops = ();
	my $prevop = "";
	my @sorted;

	$self->_setSummaryColumn($subHeading);
	$column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};
	if ($subHeading eq "") {
		$subHeading = "KB/sec";
	}


	# Sort by op-size-blksize
	@sorted = sort testcompare @{$self->{_ResultData}};

	foreach my $data (@sorted) {
		# New op/size/blksize? Push stats for previous one
		if (($prevop ne "") && ($prevop ne ${$data}[0])) {
			$self->_calcStats($prevop, $subHeading, \@ops);
			@ops = ();
		}
		$prevop = ${$data}[0];
		push @ops, ${$data}[$column];
	}
	# Push stats for the last operation
	$self->_calcStats($prevop, $subHeading, \@ops);

	return 1;
}

sub printSummary() {
	my ($self, $subHeading) = @_;

	$self->_setSummaryColumn($subHeading);
	$self->SUPER::printSummary($subHeading);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my @files = <$reportDir/noprofile/iozone-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		my $iteration = $split[-1];
		open(INPUT, $file) || die("Failed to open $file\n");

		# Skip headings
		while (<INPUT>) {
			if ($_ =~ /^\s+kB\s+reclen\s+/) {
				last;
			}
		}
		while (<INPUT>) {
			if ($_ eq "\n") {
				last;
			}
			my @elements = split(/\s+/, $_);
			my $size = $elements[1];
			my $blksize = $elements[2];

			foreach my $op (keys(%loadindex)) {
				push @{$self->{_ResultData}}, [ "$op-$size-$blksize", $iteration, $elements[$loadindex{$op}] ];
			}
		}
		close INPUT;
	}
}

1;
