# ExtractFsmarkoverhead.pm
package MMTests::ExtractFsmarkoverhead;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractFsmarkoverhead";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);
	$reportDir =~ s/overhead//;
	my $iteration = 1;

	$self->{_CompareLookup} = {
		"files/sec" => "pdiff",
		"overhead"  => "pndiff"
	};

	$reportDir =~ s/fsmark-singleoverhead/fsmark-single/;
	$reportDir =~ s/fsmark-threadedoverhead/fsmark-threaded/;

	my @clients;
	my @files = <$reportDir/noprofile/fsmark-*.log>;
	foreach my $file (@files) {
		if ($file =~ /-cmd-/) {
			next;
		}
		$file =~ s/.log$//;
		my @split = split /-/, $file;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	my @ops;
	foreach my $client (@clients) {
		my $preamble = 1;
		my $file = "$reportDir/noprofile/fsmark-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($preamble) {
				if ($line !~ /^FSUse/) {
					next;
				}
				$preamble = 0;
				next;
			}

			my @elements = split(/\s+/, $_);
			push @{$self->{_ResultData}}, [ "overhead-$client",  ++$iteration, $elements[5] ];
		}
		close INPUT;
		push @ops, "overhead-$client";
	}

	$self->{_Operations} = \@ops;
}

1;
