# ExtractMicrotput.pm
package MMTests::ExtractMicrotput;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractMicrotput";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "group-errorlines";
	$self->{_Precision} = 4;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/$profile/microtput-*-1>;
	my @threads;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @threads, $split[-2];
	}
	@threads = sort { $a <=> $b} @threads;

	foreach my $thread (@threads) {
		my $nr_samples = 0;
		foreach my $file (<$reportDir/$profile/microtput-$thread-*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /throughput:\s*([0-9.]*)/) {
					$self->addData($thread, ++$nr_samples, $1);
				}
			}
			close INPUT;
		}
	}

	$self->{_Operations} = \@threads;
}
1;
