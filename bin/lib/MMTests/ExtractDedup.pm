# ExtractDedup.pm
package MMTests::ExtractDedup;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_ModuleName} = "ExtractDedup";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName) = @_;
	my ($tp, $name);
	my @threads;

	my @files = <$reportDir/dedup-*-1.time>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}
	@threads = sort { $a <=> $b } @threads;

	foreach my $nthr (@threads) {
		my @files = <$reportDir/dedup-$nthr-*.time>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.time//;
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /([0-9]):([0-9.]+)elapsed/) {
					$self->addData($nthr, ++$nr_samples, $self->_time_to_elapsed($line));
				}
			}
			close INPUT;
		}

	}

	$self->{_Operations} = \@threads;
}
