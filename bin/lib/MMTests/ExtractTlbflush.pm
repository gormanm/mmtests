# ExtractTlbflush.pm
package MMTests::ExtractTlbflush;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops); 
use strict;

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my @ops;
	my @clients;
	my @files = <$reportDir/noprofile/tlbflush-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $iteration = 0;

		my $file = "$reportDir/noprofile/tlbflush-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		my ($user, $sys, $records);
		while (<INPUT>) {
			if ($_ =~ /.*, cost ([0-9]*)ns.*/) {
				push @{$self->{_ResultData}}, [ "nsec-$client", ++$iteration, $1 ];
				if ($iteration == 1) {
					push(@ops, "nsec-$client");
				}
			}
		}
		close INPUT;
	}

	$self->{_Operations} = \@ops;
}

1;
