# ExtractPerfpipe.pm
package MMTests::ExtractPerfpipe;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPerfpipe",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/$profile/pipe-*.log>) {
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
