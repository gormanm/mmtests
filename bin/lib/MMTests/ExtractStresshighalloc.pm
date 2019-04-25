# ExtractStresshighalloc.pm
package MMTests::ExtractStresshighalloc;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStresshighalloc",
		_DataType    => DATA_SUCCESS_PERCENT,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $file = "$reportDir/$profile/log.txt";
	my $pass = 0;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my ($dummy, $success);

		if ($_ =~ /Results Pass 1/) {
			$pass = 1;
			next;
		}
		if ($_ =~ /Results Pass 2/) {
			$pass = 2;
			next;
		}
		if ($_ =~ /while Rested/) {
			$pass = 3;
			next;
		}

		if ($_ =~ /% Success/) {
			($dummy, $dummy, $success) = split(/\s+/, $_);
			$self->addData($pass, 0, $success);
		}
	}
	close INPUT;
}

1;
