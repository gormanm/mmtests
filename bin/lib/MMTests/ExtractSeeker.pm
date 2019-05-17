# ExtractSeeker.pm
package MMTests::ExtractSeeker;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSeeker";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_DefaultPlot} = "Seeks";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $file = "$reportDir/seeker.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $iteration = 0;
	while (<INPUT>) {
		if ($_ =~ /^mark: ([0-9]*).*/) {
			$self->addData("Seeks", ++$iteration, $1);
		}
	}
	close INPUT;
}
1;
