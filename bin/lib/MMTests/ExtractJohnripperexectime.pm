# ExtractJohnripperexectime.pm
package MMTests::ExtractJohnripperexectime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractJohnripperexectime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_Opname}     = "ExecTime";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "johnripper-", "-1.log");
	foreach my $client (@clients) {
		my $iteration = 0;

		foreach my $file (<$reportDir/load-$client-*.time>) {
			$self->parse_time_elapsed($file, $client, ++$iteration);
		}
	}
}

1;
