# ExtractLibmicro.pm
package MMTests::ExtractLibmicro;
use MMTests::SummariseSingleops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseSingleops);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractLibmicro";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/noprofile/*.log>;
	my @ops;
	foreach my $file (@files) {
		my $testname = $file;
		$testname =~ s/.*\///;
		$testname =~ s/\.log$//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			if ($_ =~ /^#\s+mean of 95.*/) {
				my @elements = split(/\s+/);
				push @{$self->{_ResultData}}, [$testname, $elements[4]];
				push @ops, $testname;
			}
		}
		close INPUT;
	}
	$self->{_Operations} = \@ops;
}
1;
