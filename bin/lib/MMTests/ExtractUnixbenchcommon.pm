# ExtractUnixbench.pm
package MMTests::ExtractUnixbenchcommon;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->SUPER::initialise($subHeading);
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tp, $name);
	my $file_wk = "$reportDir/workloads";
	open(INPUT, "$file_wk") || die("Failed to open $file_wk\n");
	my @workloads = split(/ /, <INPUT>);
	$self->{_Workloads} = \@workloads;
	close(INPUT);

	my @threads;
	foreach my $wl (@workloads) {
		chomp($wl);
		my @files = <$reportDir/$wl-*-1.log>;
		foreach my $file (@files) {
			my @elements = split (/-/, $file);
			my $thr = $elements[-2];
			$thr =~ s/.log//;
			push @threads, $thr;
		}
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);

	foreach my $wl (@workloads) {
		foreach my $nthr (@threads) {
			my $nr_samples = 0;

			foreach my $file (<$reportDir/$wl-$nthr-*.log>) {
				open(INPUT, $file) || die("Failed to open $file\n");
				while (<INPUT>) {
					my $line = $_;
					my @tmp = split(/\s+/, $line);

					if ($line =~ /^Dhrystone 2 using register variables * ([0-9.]+) * ([0-9.]+) * ([0-9.]+)/) {
						$tp = $2;
					} elsif ($line =~ /^Pipe Throughput * ([0-9.]+) * ([0-9.]+) * ([0-9.]+)/) {
						$tp = $2;
					} elsif ($line =~ /^System Call Overhead * ([0-9.]+) * ([0-9.]+) * ([0-9.]+)/) {
						$tp = $2;
					} elsif ($line =~ /^Execl Throughput * ([0-9.]+) * ([0-9.]+) * ([0-9.]+)/) {
						$tp = $2;
					} elsif (/^Process Creation * ([0-9.]+) * ([0-9.]+) * ([0-9.]+)/)  {
						$tp = $2;
					} elsif (/^File .*maxblocks * ([0-9.]+) * ([0-9.]+) * ([0-9.]+)/)  {
						$tp = $2;
					} elsif (/^File .*maxblocks * ([0-9.]+) KBps/) {
						$tp = $1;
						next if <INPUT> =~ /BASELINE/;
						next if <INPUT> =~ /BASELINE/;
					} else {
						next;
					}

					$self->addData("unixbench-$wl-$nthr", ++$nr_samples, $tp);
				}

				close INPUT;
			}
		}
	}
}
