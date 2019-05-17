# ExtractLibmicro.pm
package MMTests::ExtractLibmicro;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractLibmicro";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_Precision}  = 4;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/*.log>;
	my @ops;
	foreach my $file (@files) {
		my $testname = $file;
		$testname =~ s/.*\///;
		$testname =~ s/\.log$//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my @elements = split(/\s+/);
			if ($_ =~ /^#\s+mean of 95.*/) {
				$self->addData("mean95-$testname", 0, $elements[-1]);
				push @ops, "mean95-$testname";
				next;
			}
		}
		close INPUT;
	}
	$self->{_Operations} = \@ops;
}
1;
