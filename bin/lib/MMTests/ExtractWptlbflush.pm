# ExtractWptlbflush.pm
package MMTests::ExtractWptlbflush;
use MMTests::SummariseMultiops;
use VMR::Report;
use Math::Round;
our @ISA = qw(MMTests::SummariseMultiops);

sub printDataType() {
        print "Time,TestName,Time (usec),simple";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractWptlbflush";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;
	$self->{_ExactSubheading} = 1;
	$self->{_ExactPlottype} = "simple";
	$self->{_DefaultPlot} = "1";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @ops;
	my @clients;
	my @files = <$reportDir/$profile/wp-tlbflush-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $file = "$reportDir/$profile/wp-tlbflush-$client.log";

		open(INPUT, $file) || die("Failed to open $file\n");
		my $iteration = 0;
		my $last = 0;
		while (<INPUT>) {
			my @elements = split(/\s/);
			my $t = nearest(.5, $elements[0]);

			if ($last && $t > $last * 50) {
				next;
			}
			$last = $t;
			push @{$self->{_ResultData}}, ["procs-$client", ++$iteration, $t];
		}
		push @ops, "procs-$client";
	}

	$self->{_Operations} = \@ops;
	close INPUT;
}
1;
