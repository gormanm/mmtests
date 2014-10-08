# ExtractDbench4.pm
package MMTests::ExtractDbench4;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractDbench4",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $readingOperations = 0;
	my @clients;
	my %dbench_ops = ("NTCreateX"	=> 1, "Close"	=> 1, "Rename"	=> 1,
			  "Unlink"	=> 1, "Deltree"	=> 1, "Mkdir"	=> 1,
			  "Qpathinfo"	=> 1, "WriteX"	=> 1, "ReadX"	=> 1,
			  "Qfileinfo"	=> 1, "Qfsinfo"	=> 1, "Flush"	=> 1,
			  "Sfileinfo"	=> 1, "LockX"	=> 1, "UnlockX"	=> 1,
			  "Find"	=> 1);

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
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);

				$nr_samples++;
				push @{$self->{_ResultData}}, [ "MBsec-$client",   $nr_samples, $elements[3] ];
				push @{$self->{_ResultData}}, [ "latency-$client", $nr_samples, $elements[9] ];

				next;
			}

			if ($line =~ /Operation/) {
				$readingOperations = 1;
				next;
			}

			if ($readingOperations == 1) {
				my @elements = split(/\s+/, $line);
				if ($dbench_ops{$elements[1]} == 1) {
					push @{$self->{_ExtraData}[$client]},
						[ $elements[1], $elements[3], $elements[4] ];
				}
			}
		}
		close INPUT;
	}

	my @ops;
	foreach my $client (@clients) {
		push @ops, "MBsec-$client";
	}
	foreach my $client (@clients) {
		push @ops, "latency-$client";
	}

	$self->{_Operations} = \@ops;
}

1;
