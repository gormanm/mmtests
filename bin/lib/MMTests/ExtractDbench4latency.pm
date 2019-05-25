# ExtractDbench4latency
package MMTests::ExtractDbench4latency;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "Dbench4latency.pm",
		_DataType    => DataTypes::DATA_TIME_MSECONDS,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;
	$reportDir =~ s/4latency/4/;

	@clients = $self->discover_scaling_parameters($reportDir, "dbench-", ".log.gz");

	foreach my $client (@clients) {
		my $file = "$reportDir/dbench-$client.log.gz";
		my $nr_samples = 0;

		open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);

				$nr_samples++;
				$self->addData("latency-$client", $nr_samples, $elements[9]);

				next;
			}
		}
		close INPUT;
	}
}

1;
