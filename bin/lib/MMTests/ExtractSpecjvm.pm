# ExtractSpecjvm.pm
package MMTests::ExtractSpecjvm;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpecjvm",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 27;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders}[0] = "Benchmark";
	$self->{_FieldHeaders}[1] = "Ops/min";
	$self->{_PlotHeaders}[0] = "Benchmark";
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub printSummary() {
	my ($self) = @_;

	$self->printReport();
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $section = 0;

	my $file = "$reportDir/noprofile/base/SPECjvm2008.001/SPECjvm2008.001.txt";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /======================/) {
			$section++;
			next;
		}

		if ($section == 3 && $line !~ /result:/) {
			my ($bench, $ops) = split(/\s+/, $line);
			push @{$self->{_ResultData}}, [ $bench, $ops ];
		}

		if ($section == 4 && $line =~ /iteration [0-9]+/) {
			my ($bench, $dA, $dB, $dC, $dD, $dE, $ops) = split(/\s+/, $line);
			push @{$self->{_ResultData}}, [ $bench, $ops ];
		}
	}
	close INPUT;
}

1;
