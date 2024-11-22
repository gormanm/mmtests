# ExtractKvmstart.pm
package MMTests::ExtractKvmstart;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractKvmstart";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @sizes = $self->discover_scaling_parameters($reportDir, "memhog-", ".1.time");

	foreach my $size (@sizes) {
		my @files = <$reportDir/memhog-$size.*.time>;
		my $iteration = 0;

		foreach my $file (@files) {
			$self->parse_time_elapsed($file, $size, ++$iteration);
		}
	}
}
