# ExtractWis.pm
package MMTests::ExtractWiscommon;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_ModuleName} = "ExtractWiscommon";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tp, $name);
	my $file_wk = "$reportDir/$profile/workloads";
	open(INPUT, "$file_wk") || die("Failed to open $file_wk\n");
	my @workloads = split(/,/, <INPUT>);
	$self->{_Workloads} = \@workloads;
	close(INPUT);

	my $file_models = "$reportDir/$profile/models";
	open(INPUT, "$file_models") || die("Failed to open $file_models\n");
	my @models = split(/,/, <INPUT>);
	$self->{_Models} = \@models;
	close(INPUT);

	my @threads;
	foreach my $wl (@workloads) {
		chomp($wl);
		my @files = <$reportDir/$profile/wis-$wl-*.log>;
		foreach my $file (@files) {
			my @elements = split (/-/, $file);
			my $thr = $elements[-1];
			$thr =~ s/.log//;
			push @threads, $thr;
		}
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);

	foreach my $wl (@workloads) {
		foreach my $nthr (@threads) {
			foreach my $model (@models) {
				chomp($model);
				my $file = "$reportDir/$profile/wis-$wl-$model-$nthr.log";
				my $nr_samples = 0;

				open(INPUT, $file) || die("$! Failed to open $file\n");
				while (<INPUT>) {
					my $line = $_;
					my @tmp = split(/\s+/, $line);

					# Yes, we could very well parse the 'average' immediately,
					# however, this allows the report to integrate better with
					# mmtests' own statistics.
					if ($line =~ /^min:([0-9]+) max:([0-9]+) total:([0-9]+)/) {
						$tp = $3;
					} else {
						next;
					}
					push @{$self->{_ResultData}}, [ "$wl-$model-$nthr", ++$nr_samples, $tp ];
				}
				close INPUT;
			}
		}
	}
	my @ops;
	foreach my $model (@models) {
		foreach my $wl (@workloads) {
			foreach my $nthr (@threads) {
				push @ops, "$wl-$model-$nthr"
			}
		}
	}
	$self->{_Operations} = \@ops;
}
