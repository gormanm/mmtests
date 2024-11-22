# ExtractPerfsyscall.pm
package MMTests::ExtractPerfsyscall;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPerfsyscall",
		_PlotYaxis   => DataTypes::LABEL_TIME_USECONDS,
		_PlotType    => "simple",
		_Precision   => 4,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/syscall-*.log>) {
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
	close INPUT;
}
1;
