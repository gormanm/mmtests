# ExtractRedismemtier.pm
package MMTests::ExtractRedismemtier;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractRedismemtier";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_ClientSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "redis-memtier-", "-1.log");
	foreach my $client (@clients) {
		my $iteration = 1;
		foreach my $file (<$reportDir/redis-memtier-$client-*.log>) {
			open(INPUT, $file) || die("Failed to open $file: $!\n");
			while (<INPUT>) {
				my $line = $_;
				chomp($line);

				next if $line !~ /^Totals/;

				my @elements = split(/\s+/, $line);

				$self->addData("$client-ops/sec", $iteration, $elements[1]);
				$self->addData("$client-hits/sec", $iteration, $elements[2]);
				$self->addData("$client-miss/sec", $iteration, $elements[3]);
			}
			$iteration++;
			close(INPUT);
		}
	}
}

1;
