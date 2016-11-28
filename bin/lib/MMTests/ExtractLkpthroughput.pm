# ExtractLkpthroughput.pm
package MMTests::ExtractLkpthroughput;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 14;
	$self->{_FieldLength} = $fieldLength;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
	$self->{_ModuleName} = "ExtractLkpthroughput";
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tp, $name);
	my @workloads = split(/,/, <INPUT>);
	$self->{_Workloads} = \@workloads;
	close(INPUT);

	my @threads;
	my @files = <$reportDir/$profile/lkp-*-1.log>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);

	foreach my $nthr (@threads) {
		foreach my $file (<$reportDir/$profile/lkp-$nthr-*.log>) {
			my $nr_samples = 0;

			open(INPUT, $file) || die("$! Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				my @tmp = split(/\s+/, $line);

				if ($line =~ /^throughput: ([0-9.]*)/) {
					push @{$self->{_ResultData}}, [ "tput-$nthr", ++$nr_samples, $1 ];
				}
			}
			close INPUT;
		}
	}
	my @ops;
	foreach my $nthr (@threads) {
		push @ops, "tput-$nthr"
	}
	$self->{_Operations} = \@ops;
}
