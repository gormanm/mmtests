package MMTests::ExtractDbench4;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;
	my $fieldLength = 12;
	$self->{_ModuleName} 		= "ExtractDbench4";
	$self->{_DataType}   		= DataTypes::DATA_TIME_MSECONDS;
	$self->{_PlotType}   		= "client-errorlines";
	$self->{_SubheadingPlotType}	= "simple-clients";
	$self->{_SubheadingFine}	= 1;
        $self->SUPER::initialise($reportDir, $testName);
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%-${fieldLength}.3f", "%${fieldLength}d" ];
}

sub sort_time {
	my $resultRef = shift;
	my @new_resultRef = sort { $a->[1] <=> $b->[1] } @$resultRef;
	return \@new_resultRef;
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

	my %client_time;

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
			if ($line =~ /completed in/) {
				my @elements = split(/\s+/, $line);

				# Look for what is probably a negative wrap
				next if ($elements[3] > (1<<31));

				$nr_samples++;
				my $runtime = $client_time{$elements[0]} += $elements[3];
				if ($elements[7] ne "") {
					$runtime = $elements[7];
				}

				$client_time{$elements[0]} += $elements[3];
				push @{$self->{_ResultData}}, [ "$client", $runtime / 1000, $elements[3] ];

				next;
			}
		}
		close INPUT;
	}

	$self->{_ResultData} = sort_time $self->{_ResultData};

	my @ops;
	foreach my $client (@clients) {
		push @ops, "$client";
	}

	$self->{_Operations} = \@ops;
}

1;
