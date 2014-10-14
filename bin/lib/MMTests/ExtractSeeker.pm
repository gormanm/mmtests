# ExtractSeeker.pm
package MMTests::ExtractSeeker;
use MMTests::SummariseMultiops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseMultiops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSeeker",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_ResultData  => [],
		_SummariseColumn => 2,
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/noprofile/seeker.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		if ($_ =~ /^mark: ([0-9]*).*/) {
			push @{$self->{_ResultData}}, ["Seeks", ++$iteration, $1];
		}
	}
	close INPUT;
	push @{$self->{_Operations}}, "Seeks";
}
1;
