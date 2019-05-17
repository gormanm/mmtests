# ExtractFutexwait.pm
package MMTests::ExtractFutexwait;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractFutexwait";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tp, $name);
	my @threads;

	my @files = <$reportDir/futexwait-*-1.log>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}

	@threads = sort {$a <=> $b} @threads;
	foreach my $nthr (@threads) {
		my @files = <$reportDir/futexwait-$nthr-*.log>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /Result: ([0-9]+) Kiter\/s/) {
					$self->addData($nthr, ++$nr_samples, $1);
				}
			}
			close INPUT;
		}
	}
}
