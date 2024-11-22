# ExtractOpenfoamsteps.pm
package MMTests::ExtractOpenfoamsteps;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractOpenfoamsteps";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iterations = 0;

	foreach my $file (<$reportDir/step-times.*>) {

		$iterations++;
		open (INPUT, $file);
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			chomp($line);

			my ($start_step, $state, $start_timestamp) = split(/:/, $line);
			die "$state is not start" if ($state ne "start");

			$line = <INPUT>;
			chomp($line);

			my ($end_step, $end_state, $end_timestamp) = split(/:/, $line);
			die "$end_state ($line) is not end" if ($end_state ne "end");
			die if ($end_step ne $start_step);

			$self->addData("$start_step", $iterations, $end_timestamp - $start_timestamp);
		}
	}
}
