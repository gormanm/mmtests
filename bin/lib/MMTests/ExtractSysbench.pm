# ExtractSysbench.pm
package MMTests::ExtractSysbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSysbench";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "sysbench-raw-", "-1");;
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/sysbench-raw-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				next if $line !~ /.*transactions:.*per sec/;
				my @elements = split(/\s+/, $line);
				my $ops = $elements[3];
				$ops =~ s/\(//;
				$self->addData($client, $iteration, $ops);
				$iteration++;
			}
			close INPUT;
		}
	}
}

1;
