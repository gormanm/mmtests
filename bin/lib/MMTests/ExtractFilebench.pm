# ExtractFilebench.pm
package MMTests::ExtractFilebench;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractFilebench";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	open(INPUT, "$reportDir/$profile/model") || die("Failed to detect model");
	my $case = <INPUT>;
	chomp($case);
	close(INPUT);

        my @clients;
        my @files = <$reportDir/$profile/$case-*.1>;
        foreach my $file (@files) {
                my @split = split /-/, $file;
                $split[-1] =~ s/\.1//;
                push @clients, $split[-1];
        }
        @clients = sort { $a <=> $b } @clients;

	my @ops;
	foreach my $client (@clients) {
		my $iteration = 0;
		foreach my $file (<$reportDir/$profile/$case-$client.*>) {
			open(INPUT, $file) || die("Failed to open $file");
			my ($startSetup, $endSetup, $endRun);
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				if ($line =~ /[0-9]+: ([0-9.]+): Creating fileset/) {
					$startSetup = $1;
					next;
				}
				if ($line =~ /[0-9]+: ([0-9.]+): Running/) {
					$endSetup = $1;
					next;
				}

				if ($line =~ /[0-9]+: ([0-9.]+): IO Summary:\s+([0-9]+) ops, ([0-9.]+) ops.*/) {
					push @{$self->{_ResultData}}, [ "$case-$client", ++$iteration, $3 ];
					if ($iteration == 1) {
						push @ops, "$case-$client";
					}
				}
			}
			close(INPUT);
		}
	}

	$self->{_Operations} = \@ops;
}

1;
