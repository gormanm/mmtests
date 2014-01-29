# ExtractVmrstream.pm
package MMTests::ExtractVmrstream;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

use constant DATA_STREAMTHROUGHPUT	=> 300;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractVmrstream",
		_DataType    => DATA_STREAMTHROUGHPUT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @pagesize_types;
	my %wss_sizes;

	# Get a list of backing buffer types: malloc, static etc.
	my @files = <$reportDir/noprofile/default/stream-*>;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		push @pagesize_types, $split[-1];
	}

	# Lazy, the test can handle this but the extract script doesn't
	if ($#pagesize_types > 1) {
		die("Extract script cannot handle multiple buffer types");
	}

	# Get the list of buffer sizes used during the test
	open(INPUT, "$reportDir/noprofile/default/$pagesize_types[0]/stream-Add.instances") || die("Failed to open file for wss_sizes");
	while (<INPUT>) {
		my @elements = split(/\s+/, $_);
		$wss_sizes{$elements[0]} = 1;
	}
	close INPUT;
	
	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldHeaderFormat} = [ "%-26s", "%${fieldLength}s", "%${fieldLength}s" ];
	$self->{_FieldFormat} = [ "%-26s", "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Operation", "MemSize", "MB/sec" ];
	$self->{_PlotHeaders} = [ "MemSize", "MB/sec" ];
	$self->{_PagesizeTypes} = \@pagesize_types;
	$self->{_WssSizes} = \%wss_sizes;
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my $fieldLength = $self->{_FieldLength};
	my @data = @{$self->{_ResultData}};
	my %wss_sizes = %{$self->{_WssSizes}};

	# In actuality, this is only used internally by the compare module
	# The printSummary handler for this prints multiple rows rather
	# than using a large number of columns that do not fit on the
	# screen.
	my @summaryHeaders = ("Operation");
	foreach my $wss_size (sort {$a <=> $b} keys %wss_sizes) {
		push @summaryHeaders, $wss_size;
	}
	$self->{_SummaryHeaders} = \@summaryHeaders;

	foreach my $operation ("Add", "Copy", "Scale", "Triad") {
		my @compareRow;
		push @compareRow, "$operation";
		foreach my $wss_size (sort {$a <=> $b} keys %wss_sizes) {
			my @samples;

			foreach my $row (grep(@{$_}[0] eq $operation, @data)) {
				my @rowArray = @$row;
				if ($wss_size == $rowArray[1]) {
					push @samples, $rowArray[2];
				}
			}

			push @compareRow, calc_true_mean(@samples);
		}
		push @{$self->{_SummaryData}}, \@compareRow;
	}

	return 1;
}

sub printSummary() {
	my ($self) = @_;
	my $fieldLength = $self->{_FieldLength};
	my @data = @{$self->{_ResultData}};
	my %wss_sizes = %{$self->{_WssSizes}};

	foreach my $operation ("Add", "Copy", "Scale", "Triad") {
		foreach my $wss_size (sort {$a <=> $b} keys %wss_sizes) {
			my @samples;

			foreach my $row (grep(@{$_}[0] eq $operation, @data)) {
				my @rowArray = @$row;
				if ($wss_size == $rowArray[1]) {
					push @samples, $rowArray[2];
				}
			}

			printf("%-26s %${fieldLength}d %${fieldLength}.2f\n",
				$operation, $wss_size, calc_true_mean(@samples));
		}
	}
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @pagesize_types = @{$self->{_PagesizeTypes}};

	foreach my $pagesize_type (@pagesize_types) {
		foreach my $operation ("Add", "Copy", "Scale", "Triad") {
			my $file = "$reportDir/noprofile/default/$pagesize_type/stream-$operation.instances";
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my @elements = split(/\s+/, $_);
				push @{$self->{_ResultData}}, [$operation, $elements[0], $elements[1]];
			}
			close INPUT;
		}
	}
}

1;
