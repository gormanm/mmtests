# ExtractLibmicro.pm
package MMTests::ExtractLibmicro;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractLibmicro";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_Precision}  = 4;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/*.log>;
	foreach my $file (@files) {
		my $testname = $file;
		$testname =~ s/.*\///;
		$testname =~ s/\.log$//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my @elements = split(/\s+/);
			if ($_ =~ /^#\s+mean of 95.*/) {
				$self->addData("mean95-$testname", 0, $elements[-1]);
				next;
			}
		}
		close INPUT;
	}
}
1;
