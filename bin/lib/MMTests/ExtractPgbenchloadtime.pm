# ExtractPgbenchloadtime.pm
package MMTests::ExtractPgbenchloadtime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractPgbenchloadtime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram-single";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/pgbenchloadtime/pgbench/;

	@clients = $self->discover_scaling_parameters($reportDir, "pgbench-", ".log");

	# Extract load times if available
	$iteration = 0;
	foreach my $client (@clients) {
		if (open (INPUT, "$reportDir/load-$client.time")) {
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("loadtime", ++$iteration, $self->_time_to_elapsed($_));
			}
			close INPUT;
		}
	}
}

1;
