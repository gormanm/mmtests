# ExtractCoremark.pm
package MMTests::ExtractCoremark;
use MMTests::SummariseVariableops;
our @ISA = qw(MMTests::SummariseVariableops);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractCoremark";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND,

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;
	my $nr_pthreads = -1;

	foreach my $file (<$reportDir/coremark-*.log*>) {

		my $input = $self->SUPER::open_log($file);
		while (!eof($input)) {
			my $line = <$input>;
			next if $line !~ /^CoreMark 1/;

			if ($nr_pthreads == -1 && $line =~ /([0-9]+):PThreads/) {
				$nr_pthreads = $1;
			}

			my @elements = split(/\s/, $line);
			$self->addData("Score-$nr_pthreads", ++$iteration, $elements[3]);
		}
		close($input);
	}
}
1;
