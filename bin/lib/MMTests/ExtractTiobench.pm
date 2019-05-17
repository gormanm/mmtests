# ExtractTiobench.pm
package MMTests::ExtractTiobench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractTiobench";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName) = @_;
	my $max_read = -1;

	if (open(INPUT, "$reportDir/disk-read.speed")) {
		$max_read = <INPUT>;
		close(INPUT);
	}
	$self->addData("PotentialReadSpeed", 1, $max_read);

	my @clients;
	my @files = <$reportDir/tiobench-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $reading = 0;
		my @files = <$reportDir/tiobench-$client-*.log>;
		foreach my $file (@files) {
			my $op;
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;

				if ($reading) {
					my @elements = split(/\s+/, $_);
					if ($elements[4] =~ /#/) {
						$elements[4] = -1;
					}
					$self->addData("$op-MB/sec-$client", $iteration, $elements[4]);
					$reading = 0;
					next;
				}

				chomp($line);
				if ($line eq "Sequential Reads") {
					$reading = 1;
					$op = "SeqRead";
					next;
				}
				if ($line eq "Random Reads") {
					$reading = 1;
					$op = "RandRead";
					next;
				}
				if ($line eq "Sequential Writes") {
					$reading = 1;
					$op = "SeqWrite";
					next;
				}
				if ($line eq "Random Writes") {
					$reading = 1;
					$op = "RandWrite";
					next;
				}
			}
			close INPUT;
		}
	}

	my @ops;
	push @ops, "PotentialReadSpeed";
	foreach my $op ("SeqRead-MB/sec", "RandRead-MB/sec", "SeqWrite-MB/sec", "RandWrite-MB/sec") {
		foreach my $client (@clients) {
			push @ops, "$op-$client";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
