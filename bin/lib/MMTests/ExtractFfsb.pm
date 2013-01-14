# ExtractFfsb.pm
package MMTests::ExtractFfsb;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractFfsb",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 13;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders}[0] = "Benchmark";
	$self->{_FieldHeaders}[1] = "Ops/sec";
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
	my $reading_totals = 0;

	my $file = "$reportDir/noprofile/ffsb.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /Total Results/) {
			$reading_totals++;
			next;
		}

		if ($reading_totals == 1 && $line =~ /:/) {
			my ($dA, $oper, $dB, $dC, $ops, $dD) = split(/\s+/, $line);
			push @{$self->{_ResultData}}, [ $oper, $ops ];
		}
		if ($reading_totals == 1 && $line =~ /^-/) {
			$reading_totals = 2;
		}
		if ($reading_totals == 2 && $line =~ /([0-9.]+) Transactions per Second/) {
			push @{$self->{_ResultData}}, [ "Transactions", $1 ];
		}
		if ($reading_totals == 2 && $line =~ /Read Throughput: ([0-9.]+)MB\/sec/) {
			push @{$self->{_ResultData}}, [ "Read", $1 ];
		}
		if ($reading_totals == 2 && $line =~ /Write Throughput: ([0-9.]+)MB\/sec/) {
			push @{$self->{_ResultData}}, [ "Write", $1 ];
			$reading_totals = 0;
		}
	}
	close INPUT;
}

1;
