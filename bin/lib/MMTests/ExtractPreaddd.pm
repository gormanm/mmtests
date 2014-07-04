# ExtractPreaddd.pm
package MMTests::ExtractPreaddd;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPreaddd",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	print "Iteration,Throughput,MB/sec";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	
	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%${fieldLength}d", "%${fieldLength}d", "%$fieldLength.2f", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Copy", "Throughput", "Duration" ];
	$self->{_SummariseColumn} = 1;
}

sub _setSummaryColumn() {
	my ($self, $subHeading) = @_;
	$self->{_SummariseColumn} = 1;

	if ($subHeading eq "ddtime") {
		$self->{_SummariseColumn} = 2;
	}
	if ($subHeading eq "elapsed") {
		$self->{_SummariseColumn} = 3;
	}
}

sub printPlot() {
	my ($self, $subHeading) = @_;

	$self->_setSummaryColumn($subHeading);
	$self->SUPER::printPlot();
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	$self->_setSummaryColumn($subHeading);
	$self->SUPER::extractSummary($subHeading);
}

sub printSummary() {
	my ($self, $subHeading) = @_;

	$self->_setSummaryColumn($subHeading);
	$self->SUPER::printSummary($subHeading);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my @files = <$reportDir/noprofile/dd.*>;
	my $iterations = @files;

	my $nr_copies = 0;
	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file"); 
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			next if $line !~ /copied/;

			my @elements = split(/\s+/, $line);
			my $time_value = $elements[5];
			if ($elements[6] ne "s,") {
				die("Unexpected time format '$elements[6]'");
			}

			my $tput_value;
			if ($elements[8] eq "MB/s") {
				$tput_value = $elements[7];
			} elsif ($elements[8] eq "GB/s") {
				$tput_value = $elements[7] * 1024;
			} else {
				die("Unrecognised tput rate '$elements[7]'");
			}

			push $self->{_ResultData}, [ ++$nr_copies, $tput_value, $time_value ];
		}

		close(INPUT);
	}
}

1;
