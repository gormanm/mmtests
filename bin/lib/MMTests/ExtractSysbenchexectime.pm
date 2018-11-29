# ExtractSysbenchexectime.pm
package MMTests::ExtractSysbenchexectime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSysbenchexectime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	$reportDir =~ s/sysbenchexectime/sysbench/;

	my @clients;
	my @files = <$reportDir/$profile/default/sysbench-raw-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/$profile/default/time-$client-*>;
		foreach my $file (@files) {


			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				push @{$self->{_ResultData}}, [ $client, ++$iteration, $self->_time_to_elapsed($_) ];
			}
			close(INPUT);
		}
	}

	$self->{_Operations} = \@clients;
}

1;
