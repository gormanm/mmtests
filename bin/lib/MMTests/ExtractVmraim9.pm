# ExtractVmraim9.pm
package MMTests::ExtractVmraim9;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractVmraim9",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders}[0] = "Operation";
	$self->{_PlotHeaders}[0] = "Operation";
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
	my $file = "$reportDir/noprofile/aim9/log.txt";
	my @aim9_tests = ("creat-clo", "page_test", "brk_test", "signal_test", "exec_test", "fork_test", "link_test");

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {

		# All the lines of interest have "second" in there somewhere
		if ($_ !~ /second/) {
			next;
		}

		my $line = $_;
		foreach $aim9_test (@aim9_tests) {
			my @elements = split(/\s+/, $line);

			if ($elements[2] eq $aim9_test) {
				push @{$self->{_ResultData}}, [ $aim9_test, $elements[6] ];
			}
		}
	}
	close INPUT;
}

1;
