# ExtractPedsort.pm
package MMTests::ExtractPedsort;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractPedsort";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_MINUTE;
	$self->{_PlotType}   = "thread-errorlines";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @threads = $self->discover_scaling_parameters($reportDir, "pedsort-", "-1.log");;
	foreach my $nthr (@threads) {
		my @files = <$reportDir/pedsort-$nthr-*.log>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~  /([0-9]+)i ([0-9]+)o throughput: ([0-9]+.[0-9]+) jobs\/hour\/core$/) {
					$self->addData($nthr, ++$nr_samples, $3*60); # convert to ops/min/core
				}
			}
			close INPUT;
		}
	}
}

1;
