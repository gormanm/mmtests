# ExtractKernbench.pm
package MMTests::ExtractKernbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractKernbench";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @jobs = $self->discover_scaling_parameters($reportDir, "kernbench-", "-1.time");

	foreach my $job (@jobs) {
		my @files = <$reportDir/kernbench-$job-*.time>;
		my $iteration = 0;

		foreach my $file (@files) {
			$self->parse_time_all($file, $job, ++$iteration);
		}
	}

	my @ratioops;
	foreach my $job (@jobs) {
		push @ratioops, "elsp-$job";
	}
	$self->{_RatioOperations} = \@ratioops;
}
