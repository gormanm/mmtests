# ExtractStresshighalloc.pm
package MMTests::ExtractStresshighalloc;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

use constant DATA_STRESSHIGHALLOC	=> 400;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStresshighalloc",
		_DataType    => DATA_STRESSHIGHALLOC,
		_ResultData  => [],
		_ExtraData   => [],
		_PlotData    => [],
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "PercentageAllocated,Attempt,Latency (cycles),stress-highalloc";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();
	my $fieldLength = 12;
	$self->{_TestName} = $testName;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_SummaryHeaders} = [ "Pass", "Success" ];
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "Pass", "Success" ];
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d" ];
	$self->{_ExtraHeaders} = [ "Pass", "Attempt", "Result", "Latency" ];
	$self->{_ExtraLength} = $self->{_FieldLength};
	$self->{_ExtraFormat} = [ "%-${fieldLength}d", "%-${fieldLength}d", "%${fieldLength}s" , "%${fieldLength}d" ];
}

sub _setSummaryPass() {
	my ($self, $subHeading) = @_;
	
	if ($subHeading =~ /latency/) {
		my @elements = split(/-/, $subHeading);
		my $pass = $elements[1];
		$self->{_SummarisePass} = $pass;
	} else {
		die("Unrecognised summarise header '$subHeading' for stress-highalloc");
	}
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my $fieldLength = $self->{_PlotLength};

	$self->_setSummaryPass($subHeading);

	# Extract the data
	foreach my $row (@{$self->{_ExtraData}}) {
		my @rowArray = @{$row};
		if ($rowArray[0] == $self->{_SummarisePass}) {
			push @{$self->{_PlotData}}, [ $rowArray[3] ];
		}
	}

	$self->{_PrintHandler}->printRow($self->{_PlotData}, $self->{_FieldLength}, "%-${fieldLength}d");
}

sub printSummary() {
	my ($self, $subHeading) = @_;
	$self->printReport();
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $file = "$reportDir/noprofile/log.txt";
	my $pass = 0;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my ($dummy, $success);

		if ($_ =~ /Results Pass 1/) {
			$pass = 1;
			next;
		}
		if ($_ =~ /Results Pass 2/) {
			$pass = 2;
			next;
		}
		if ($_ =~ /while Rested/) {
			$pass = 3;
			next;
		}

		if ($_ =~ /^([0-9]+) (\w+) ([0-9]+)/) {
			if ($2 eq "success" || $2 eq "failure") {
				push @{$self->{_ExtraData}}, [ $pass, $1, $2, $3 ];
			}
			next;
		}

		if ($_ =~ /% Success/) {
			($dummy, $dummy, $success) = split(/\s+/, $_);
			push @{$self->{_ResultData}}, [ $pass, $success ];
		}
	}
	close INPUT;
}

1;
