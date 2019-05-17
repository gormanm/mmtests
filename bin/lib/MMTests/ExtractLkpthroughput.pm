# ExtractLkpthroughput.pm
package MMTests::ExtractLkpthroughput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractLkpthroughput";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tp, $name);
	my @workloads = split(/,/, <INPUT>);
	$self->{_Workloads} = \@workloads;
	close(INPUT);

	my @threads;
	my @files = <$reportDir/lkp-*-1.log>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);

	foreach my $nthr (@threads) {
		foreach my $file (<$reportDir/lkp-$nthr-*.log>) {
			my $nr_samples = 0;

			open(INPUT, $file) || die("$! Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				my @tmp = split(/\s+/, $line);

				if ($line =~ /^throughput: ([0-9.]*)/) {
					$self->addData("tput-$nthr", ++$nr_samples, $1);
				}
			}
			close INPUT;
		}
	}
}
