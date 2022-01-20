# ExtractSysbenchcpu.pm
package MMTests::ExtractSysbenchcpu;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSysbenchcpu";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @threads = $self->discover_scaling_parameters($reportDir, "sysbench-raw-", "-1");

	foreach my $thread (@threads) {
		my $iteration = 0;
		foreach my $file (<$reportDir/sysbench-raw-$thread-*>) {
			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;

				if ($line =~ /events per second:\s*(.*)/) {
					$self->addData($thread, ++$iteration, $1);
				}
			}
			close($input);
		}
	}
}

1;
