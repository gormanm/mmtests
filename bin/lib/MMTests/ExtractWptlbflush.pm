# ExtractWptlbflush.pm
package MMTests::ExtractWptlbflush;
use MMTests::SummariseVariabletime;
use VMR::Report;
use Math::Round;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractWptlbflush",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_ResultData  => [],
		_PlotType    => "simple",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my $file = "$reportDir/$profile/wp-tlbflush.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		my @elements = split(/\s/);
		my $t = nearest(.5, $elements[0]);
		push @{$self->{_ResultData}}, ["Time", ++$iteration, $t];
	}

	$self->{_Operations} = [ "Time" ];
	close INPUT;
}
1;
