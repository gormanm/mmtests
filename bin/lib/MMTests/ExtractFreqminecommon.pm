# ExtractFreqmine.pm
package MMTests::ExtractFreqminecommon;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_ModuleName} = "ExtractFreqmine";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my @threads;

	my @files = <$reportDir/$profile/freqmine-*-1.log>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}

	foreach my $nthr (@threads) {
		my @files = <$reportDir/$profile/freqmine-$nthr-*.log>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /cost ([0-9.]+) seconds, the FPgrowth cost ([0-9.]+) seconds/) {
					my $tottime = $1 + $2;
					push @{$self->{_ResultData}}, [ $nthr, ++$nr_samples, $tottime ];
				}
			}
			close INPUT;
		}

	}

	my @ops = sort {$a <=> $b} @threads;
	$self->{_Operations} = \@ops;

}
