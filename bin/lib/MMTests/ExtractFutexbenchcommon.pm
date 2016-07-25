# ExtractFutexbench.pm
package MMTests::ExtractFutexbenchcommon;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f%%" ];
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tp, $name);
	my $file_wk = "$reportDir/noprofile/workloads";
	open(INPUT, "$file_wk") || die("Failed to open $file_wk\n");
	my @workloads = split(/ /, <INPUT>);
	$self->{_Workloads} = \@workloads;
	close(INPUT);

	my @threads;
	foreach my $wl (@workloads) {
		chomp($wl);
		my @files = <$reportDir/noprofile/$wl-*.log>;
		foreach my $file (@files) {
			my @elements = split (/-/, $file);
			my $thr = $elements[-1];
			$thr =~ s/.log//;
			push @threads, $thr;
		}
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);
	my %futexTypesSeen;

	foreach my $nthr (@threads) {
		foreach my $wl (@workloads) {
			my $file = "$reportDir/noprofile/$wl-$nthr.log";
			my $futexType = "private";
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				my @tmp = split(/\s+/, $line);

				if ($line =~ /shared/) {
					$futexType = "shared";
				}

				if ($line =~ /.*futexes:.* \[ ([0-9]+) ops\/sec.*/) {
					$tp = $1;
				} elsif ($line =~ /.*: Requeued.* in ([0-9.]+) ms/) {
					$tp = $1;
				} elsif ($line =~ /.*: Wokeup.* in ([0-9.]+) ms/) {
					$tp = $1;
				} else {
					next;
				}

				$futexTypesSeen{$futexType} = 1;
				push @{$self->{_ResultData}}, [ "$wl-$futexType-$nthr", ++$nr_samples, $tp ];
			}

			close INPUT;
		}
	}

	my @ops;
	foreach my $futexType (sort keys %futexTypesSeen) {
		foreach my $wl (@workloads) {
			foreach my $nthr (@threads) {
				push @ops, "$wl-$futexType-$nthr"
			}
		}
	}
	$self->{_Operations} = \@ops;
}
