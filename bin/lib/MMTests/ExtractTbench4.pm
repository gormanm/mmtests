# ExtractTbench4
package MMTests::ExtractTbench4;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractTbench4";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_ExactPlottype} = "simple";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;

	@clients = $self->discover_scaling_parameters($reportDir, "tbench-", ".log.gz");

	foreach my $client (@clients) {
		my $nr_samples = 0;

		my $input = $self->SUPER::open_log("$reportDir/tbench-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /execute/) {
				$line =~ s/^\s+//;
				my @elements = split(/\s+/, $line);

				$self->addData("$client", ++$nr_samples, $elements[2]);
			}
		}
		close($input);
	}
}

1;
