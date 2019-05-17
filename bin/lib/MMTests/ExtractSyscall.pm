# ExtractSyscall.pm
package MMTests::ExtractSyscall;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSyscall",
		_DataType    => DataTypes::DATA_TIME_CYCLES,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $file = "$reportDir/syscall.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		my @elements = split(/\s/);
		$self->addData("Time", ++$iteration, $elements[3]);
	}
	close INPUT;
}
1;
