# ExtractFsmark.pm
package MMTests::ExtractFsmark;
use MMTests::SummariseVariableops;
our @ISA = qw(MMTests::SummariseVariableops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractFsmark";
	$self->{_DataType}   = MMTests::Extract::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $iteration = 1;

	$self->{_CompareLookup} = {
		"files/sec" => "pdiff",
		"overhead"  => "pndiff"
	};

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
		my $file = "$reportDir/noprofile/fsmark-$client.log";
		my $preamble = 1;
		my $enospace = 0;
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

			if ($line =~ /Insufficient free space/) {
				$enospace = 1;
			}

			if ($enospace) {
				next;
			}

			my @elements = split(/\s+/, $_);
			push @{$self->{_ResultData}}, [ "files/sec-$client", ++$iteration, $elements[4] ];
		}
		close INPUT;
		push @ops, "files/sec-$client";
	}

	$self->{_Operations} = \@ops;
}

1;
