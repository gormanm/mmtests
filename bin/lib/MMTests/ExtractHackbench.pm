# ExtractHackbench.pm
package MMTests::ExtractHackbench;
use MMTests::SummariseMultiops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseMultiops);

my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractHackbench",
		_DataType    => MMTests::Extract::DATA_TIME_SECONDS,
		_ResultData  => [],
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/noprofile/hackbench.*>;
	my @threads;
	foreach my $file (@files) {
		my @split = split /\./, $file;
		push @threads, $split[-1];
	}
	@threads = sort { $a <=> $b} @threads;

	foreach my $thread (@threads) {
		my $file = "$reportDir/noprofile/hackbench.$thread";
		my $nr_samples = 0;
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			if ($_ !~ /^Time: (.*)/) {
				next;
			}
			my $walltime = $1;
			push @{$self->{_ResultData}}, [$thread, ++$nr_samples, $walltime];
		}
		close INPUT;
	}

	$self->{_Operations} = \@threads;
}
1;
