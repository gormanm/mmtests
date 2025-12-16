# ExtractPgbenchexectime.pm
package MMTests::ExtractPgbenchexectime;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractPgbenchexectime";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Opname}     = "ExecTime";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;

	@clients = $self->discover_scaling_parameters($reportDir, "pgbench-", ".log");
	foreach my $client (@clients) {
		$self->parse_time_elapsed("$reportDir/time-$client", $client, 0);
	}
}

1;
