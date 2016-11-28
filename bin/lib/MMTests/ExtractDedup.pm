# ExtractDedup.pm
package MMTests::ExtractDedup;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
	$self->{_ModuleName} = "ExtractDedup";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f%%" ];
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Threads";
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tp, $name);
	my @threads;

	my @files = <$reportDir/$profile/dedup-*-1.time>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}

	foreach my $nthr (@threads) {
		my @files = <$reportDir/$profile/dedup-$nthr-*.time>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.time//;
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /([0-9]):([0-9.]+)elapsed/) {
					my $tottime = ($1 * 60) + $2;
					push @{$self->{_ResultData}}, [ $nthr, ++$nr_samples, $tottime ];
				}
			}
			close INPUT;
		}

	}

	my @ops = sort {$a <=> $b} @threads;
	$self->{_Operations} = \@ops;

}
