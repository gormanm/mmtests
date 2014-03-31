# ExtractLibmicro.pm
package MMTests::ExtractLibmicro;
use MMTests::Extract;
use VMR::Report;
our @ISA = qw(MMTests::Extract); 

my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractLibmicro",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => [],
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	print "usecs/call,Test,Time"
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

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
	my $fieldLengthA = $self->{_FieldLength};
	my $fieldLengthB = $self->{_FieldLength} - 1;
	$self->{_FieldFormat} = [ "%-${fieldLengthA}s", "%$fieldLengthB.3f" ];
	$self->{_FieldHeaders} = [ "Test", "usecs/call" ];
	$self->{_PlotHeaders} = [ "Test", "usecs/call" ];
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/noprofile/*.log>;
	foreach my $file (@files) {
		my $testname = $file;
		$testname =~ s/.*\///;
		$testname =~ s/\.log$//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			if ($_ =~ /^$testname /) {
				my @elements = split(/\s+/);
				push @{$self->{_ResultData}}, [$testname, $elements[3]];
			}
		}
		close INPUT;
	}
}
1;
