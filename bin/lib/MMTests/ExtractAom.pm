# ExtractAom.pm
package MMTests::ExtractAom;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractAom";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @threads = $self->discover_scaling_parameters($reportDir, "time-", "");

	foreach my $thread (@threads) {
		my @files = <$reportDir/time-$thread>;
		my $iteration = 0;

		foreach my $file (@files) {
			$self->parse_time_all($file, $thread, ++$iteration);
		}
	}

	my @ratioops;
	foreach my $thread (@threads) {
		push @ratioops, "elsp-$thread";
	}
	$self->{_RatioOperations} = \@ratioops;
}
