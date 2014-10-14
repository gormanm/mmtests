# ExtractSiege.pm
package MMTests::ExtractSiege;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractDbench4";
	$self->{_DataType}   = MMTests::Extract::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @ops;
	my @clients;
	my @files = <$reportDir/noprofile/siege-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my @files = <$reportDir/noprofile/siege-$client-*.log>;
		my $iteration = 0;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				next if $line !~ /Transaction rate:/;
				my @elements = split(/\s+/, $line);
				push @{$self->{_ResultData}}, [ $client, ++$iteration, $elements[-2] ];
				if ($iteration == 1) {
					push @ops, $client;
				}
			}
			close INPUT;
		}
	}
	$self->{_Operations} = \@ops;
}

1;
