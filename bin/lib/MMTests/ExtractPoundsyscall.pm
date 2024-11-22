# ExtractPoundsyscall.pm
package MMTests::ExtractPoundsyscall;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractPoundsyscall";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @jobs = $self->discover_scaling_parameters($reportDir, "pound_syscall-", "-2.time");

	foreach my $job (@jobs) {
		my @files = <$reportDir/pound_syscall-$job-*.time>;
		my $iteration = 0;

		foreach my $file (@files) {
			$self->parse_time_elapsed($file, $job, ++$iteration);
		}
	}

	my @ratioops;
	foreach my $job (@jobs) {
		push @ratioops, "elsp-$job";
	}
	$self->{_RatioOperations} = \@ratioops;
}
