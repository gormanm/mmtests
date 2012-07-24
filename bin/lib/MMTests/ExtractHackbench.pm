# ExtractHackbench.pm
package MMTests::ExtractHackbench;
use MMTests::Extract;
use VMR::Report;
our @ISA = qw(MMTests::Extract); 

my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractHackbench",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => [],
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	my @files = <$reportDir/noprofile/hackbench.*>;
	foreach my $file (@files) {
		my @split = split /\./, $file;
		push @_threads, $split[-1];
	}
	@_threads = sort { $a <=> $b} @_threads;

	$self->SUPER::initialise($reportDir, $testName);
	my $fieldLengthA = $self->{_FieldLength};
	my $fieldLengthB = $self->{_FieldLength} - 1;
	$self->{_FieldFormat} = [ "%-${fieldLengthA}d", "%$fieldLengthB.3f" ];
	$self->{_FieldHeaders}[0] = "Threads";
	$self->{_PlotHeaders}[0] = "Threads";
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	foreach my $thread (@_threads) {
		my $file = "$reportDir/noprofile/hackbench.$thread";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			if ($_ !~ /^Time: (.*)/) {
				next;
			}
			my $walltime = $1;
			push @{$self->{_ResultData}}, [$thread, $walltime];
		}
		close INPUT;
	}
}
1;
