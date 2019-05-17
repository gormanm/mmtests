# ExtractSysbenchloadtime.pm
package MMTests::ExtractSysbenchloadtime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSysbenchloadtime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram-single";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	$reportDir =~ s/sysbenchloadtime/sysbench/;

	my @clients;
	my @files = <$reportDir/default/sysbench-raw-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract load times if available
	$iteration = 0;
	foreach my $client (@clients) {
		if (open (INPUT, "$reportDir/default/load-$client.time")) {
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("loadtime", ++$iteration, $self->_time_to_elapsed($_));
			}
			close INPUT;
		}
	}
}

1;
