# ExtractDbench4time
package MMTests::ExtractDbench4;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractDbench4";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_MSECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

        $self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/dbench-*.log>;
	if ($files[0] eq "") {
		@files = <$reportDir/noprofile/tbench-*.log>;
	}
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $nr_samples = 0;
		my $file = "$reportDir/noprofile/dbench-$client.log";
		if (! -e $file) {
			$file = "$reportDir/noprofile/tbench-$client.log";
		}
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			$line =~ s/^\s+//;
			if ($line =~ /completed in/) {
				my @elements = split(/\s+/, $line);

				$nr_samples++;
				push @{$self->{_ResultData}}, [ "msec-$client", $nr_samples, $elements[3] ];

				next;
			}
		}
		close INPUT;
	}

	my @ops;
	foreach my $client (@clients) {
		push @ops, "msec-$client";
	}

	$self->{_Operations} = \@ops;
}

1;
