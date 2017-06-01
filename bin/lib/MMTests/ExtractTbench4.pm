# ExtractTbench4
package MMTests::ExtractTbench4;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractTbench4";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
        $self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my @clients;

	my @files = <$reportDir/$profile/dbench-*.log>;
	if ($files[0] eq "") {
		@files = <$reportDir/$profile/tbench-*.log>;
	}
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $nr_samples = 0;
		my $file = "$reportDir/$profile/dbench-$client.log";
		if (! -e $file) {
			$file = "$reportDir/$profile/tbench-$client.log";
		}
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			$line =~ s/^\s+//;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $line);

				$nr_samples++;
				push @{$self->{_ResultData}}, [ "mb/sec-$client", $nr_samples, $elements[2] ];

				next;
			}
		}
		close INPUT;
	}

	my @ops;
	foreach my $client (@clients) {
		push @ops, "mb/sec-$client";
	}

	$self->{_Operations} = \@ops;
}

1;
