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

	foreach my $file (<$reportDir/coremark-*.log*>) {

		my $input = $self->SUPER::open_log($file);
		while (!eof($input)) {
			my $line = <$input>;
			next if $line !~ /^CoreMark 1/;

			my @elements = split(/\s/, $line);
			$self->addData("Score", ++$iteration, $elements[3]);
		}
		close($input);
	}
}
1;
