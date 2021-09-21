# ExtractStutterp.pm
package MMTests::ExtractStutterp;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);

use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractStutter";
	$self->{_DataType}   = DataTypes::DATA_TIME_MSECONDS;
	$self->{_Precision}  = 4;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @workers = $self->discover_scaling_parameters($reportDir, "mmap-latency-", ".log");

	foreach my $worker (@workers) {
		my $nr_samples = 0;

		my $input = $self->SUPER::open_log("$reportDir/mmap-latency-$worker.log");
		while (<$input>) {
			my ($instances, $latency) = split(/ /);
			for (my $i = 0; $i < $instances; $i++) {
				$self->addData("mmap-$worker", $nr_samples++, $latency / 1000000);
			}
		}
	}
	close(INPUT);
}
1;
