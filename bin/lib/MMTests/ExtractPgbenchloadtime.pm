# ExtractPgbenchloadtime.pm
package MMTests::ExtractPgbenchloadtime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractPgbenchloadtime";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "histogram-single";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "pgbench-", ".log");
	foreach my $client (@clients) {
		$self->parse_time_elapsed("$reportDir/load-$client.time", $client, 0);
	}
}

1;
