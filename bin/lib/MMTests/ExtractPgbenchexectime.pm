# ExtractPgbenchexectime.pm
package MMTests::ExtractPgbenchexectime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractPgbenchexectime";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/pgbenchexectime/pgbench/;

	my @files = <$reportDir/noprofile/default/pgbench-raw-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/noprofile/default/time-$client-*>;
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
