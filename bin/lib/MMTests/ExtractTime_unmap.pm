# ExtractTime_unmap.pm
package MMTests::ExtractTime_unmap;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTime_unmap",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/unmap-*.log>) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			$self->addData("Time", ++$iteration, $line);
		}
		close(INPUT);
	}
	close INPUT;
}
1;
