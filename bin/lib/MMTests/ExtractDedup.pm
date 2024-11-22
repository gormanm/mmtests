# ExtractDedup.pm
package MMTests::ExtractDedup;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractDedup";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @threads = $self->discover_scaling_parameters($reportDir, "dedup-", "-1.time");

	foreach my $nthr (@threads) {
		my @files = <$reportDir/dedup-$nthr-*.time>;
		my $iteration = 0;

		foreach my $file (@files) {
			$self->parse_time_elapsed($file, $nthr, ++$iteration);
		}
	}
}
