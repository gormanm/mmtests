# ExtractCyclictest.pm
package MMTests::ExtractCyclictest;
use MMTests::SummariseVariabletime;
use VMR::Report;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractCyclictest",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/noprofile/cyclictest.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		my $max;

		if ($_ !~ /^.*Max: (.*)/) {
			next;
		}
		$max = int($1);
		push @{$self->{_ResultData}}, [ "Time", ++$iteration, $max];
	}
	close INPUT;

	$self->{_Operations} = [ "Time" ];
}
