# ExtractTimeexit.pm
package MMTests::ExtractTimeexit;
use MMTests::SummariseVariabletime;
use VMR::Report;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTimeexit",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_ResultData  => [],
		_Precision   => 6,
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/noprofile/timeexit.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $nr_samples = 0;
	while (<INPUT>) {
		my @elements = split(/\s+/);
		push @{$self->{_ResultData}}, ["procs-$elements[0]", ++$nr_samples, $elements[1] * 1000];
		if ($nr_samples == 1) {
			push @{$self->{_Operations}}, "procs-$elements[0]";
		}
	}
	close INPUT;
}
1;
