# ExtractDbench4latency
package MMTests::ExtractDbench4latency;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName}	= "ExtractDbench4latency";
	$self->{_DataType}	= DataTypes::DATA_TIME_MSECONDS,
	$self->{_LogPrefix}	= "dbench";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = $self->discover_scaling_parameters($reportDir, "$self->{_LogPrefix}-", ".log.gz");

	foreach my $client (@clients) {
		my $nr_samples = 0;

		my $input = $self->SUPER::open_log("$reportDir/$self->{_LogPrefix}-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);

				$nr_samples++;
				$self->addData("latency-$client", $nr_samples, $elements[9]);

				next;
			}
		}
		close($input);
	}
}

1;
