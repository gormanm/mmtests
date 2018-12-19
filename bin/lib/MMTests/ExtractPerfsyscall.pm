# ExtractPerfsyscall.pm
package MMTests::ExtractPerfsyscall;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPerfsyscall",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_ResultData  => [],
		_PlotType    => "simple",
		_Precision   => 4,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/$profile/syscall-*.log>) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			$line =~ s/^\s+|\s+$//g;

			my @elements = split(/\s/, $line);
			next if ($elements[1] ne "usecs/op");
			$self->addData("Time", ++$iteration, $elements[0]);
		}
		close(INPUT);
	}

	$self->{_Operations} = [ "Time" ];
	close INPUT;
}
1;
