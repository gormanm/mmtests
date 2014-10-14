# ExtractDbench3.pm
package MMTests::ExtractDbench3;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractDbench3";
	$self->{_DataType}   = MMTests::Extract::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my @clients;
	my @ops;

	my @files = <$reportDir/noprofile/dbench-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $file = "$reportDir/noprofile/dbench-$client.log";
		my $nr_samples = 0;
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);
				$nr_samples++;
				push @{$self->{_ResultData}}, [ "MBsec-$client", $nr_samples, $elements[3] ];

				if ($nr_samples == 1) {
					push @ops, "MBsec-$client";
				}
			}
		}
		close INPUT;
	}
	$self->{_Operations} = \@ops;
}

1;
