# ExtractSpinplace.pm
package MMTests::ExtractSpinplace;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSpinplace";
	$self->{_DataType}   = DataTypes::DATA_USAGE_PERCENT;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	foreach my $file (<$reportDir/mpstat-*.log*>) {
		my $input = $self->SUPER::open_log($file);
		while (!eof($input)) {
			my $line = <$input>;
			next if $line !~ /^Average:/;
			next if $line =~ /^CPU/;

			my @elements = split(/\s+/, $line);
			$self->addData("Avg-$elements[1]", 1, 100-$elements[-1]);
		}
	}
	close($input);
}
1;
