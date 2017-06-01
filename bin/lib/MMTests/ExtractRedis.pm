# ExtractRedis.pm
package MMTests::ExtractRedis;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractRedis";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_ClientSubheading} = 1;
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my %opNames;

	my @clients;
	my @files = <$reportDir/$profile/redis-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $iteration = 1;
		foreach my $file (<$reportDir/$profile/redis-$client-*.log>) {
			open(INPUT, $file) || die("Failed to open $file: $!\n");
			while (<INPUT>) {
				my $line = $_;
				chomp($line);

				my @elements = split(/,/, $line);
				$elements[0] =~ s/ \(([0-9]+) keys\)/-$1/;
				$elements[0] =~ s/ \(.*\)//;
				$elements[0] =~ s/"//g;
				$elements[1] =~ s/"//g;

				$opNames{$elements[0]} = 1;
				push @{$self->{_ResultData}}, [ "$client-$elements[0]", $iteration, $elements[1] ];
			}
			$iteration++;
			close(INPUT);
		}
	}

	my @ops;
	my @opNameSorted = sort keys %opNames;
	foreach my $client (@clients) {
		foreach my $opName (@opNameSorted) {
			push @ops, "$client-$opName";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
