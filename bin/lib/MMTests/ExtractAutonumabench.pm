# ExtractCputime.pm
package MMTests::ExtractAutonumabench;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractAutonumabench",
		_DataType    => MMTests::Extract::DATA_CPUTIME,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}s" ];
	$self->{_FieldHeaders} = [ "Binding", "User", "System", "Elapsed", "CPU" ];
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $bindTypes;

	my @files = <$reportDir/noprofile/time.*>;
	foreach my $file (@files) {
		my @split = split /\./, $file;
		my $bindType = $split[-1];
		push @bindTypes, $bindType;

		open(INPUT, $file) || die("Failed to open $file\n");
		$_ = <INPUT>;
		$_ =~ tr/[a-zA-Z]%//d;
		($user, $system, $elapsed, $cpu) = split(/\s/, $_);
		my ($minutes, $seconds) = split(/:/, $elapsed);
		$elapsed = $minutes * 60 + $seconds;
		
		push @{$self->{_ResultData}}, [ $bindType, $user, $system, $elapsed, $cpu ];
		close INPUT;
	}
	$self->{_BindTypes} = \@bindTypes;
}

1;
