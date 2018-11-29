# ExtractFilelockperf.pm
package MMTests::ExtractFilelockperfcommon;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_TestName} = $testName;
	$self->{_ModuleName} = "ExtractFilelockperf";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise();
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

	my $file_locktypes = "$reportDir/$profile/locktypes";
	open(INPUT, "$file_locktypes") || die("Failed to open $file_locktypes\n");
	my @locktypes = split(/,/, <INPUT>);
	$self->{_Locktypes} = \@locktypes;
	close(INPUT);

	my $file_iter = "$reportDir/$profile/iterations";
	open(INPUT, "$file_iter") || die("Failed to open $file_iter\n");
	my @i = <INPUT>;
	my $iterations = $i[0];
	close(INPUT);

	my @threads;
	foreach my $wl (@workloads) {
	    chomp($wl);
	    foreach my $type (@locktypes) {
		chomp($type);

		my @files = <$reportDir/$profile/filelockperf-$wl-1-$type-*.log>;
		foreach my $file (@files) {
			my @elements = split (/-/, $file);
			my $thr = $elements[-1];
			$thr =~ s/.log//;

			push @threads, $thr;
		}
	    }
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);

	foreach my $wl (@workloads) {
		chomp($wl);
		foreach my $nthr (@threads) {
			foreach my $type (@locktypes) {
				chomp($type);

				foreach my $iter (1..$iterations) {
					my $file = "$reportDir/$profile/filelockperf-$wl-$iter-$type-$nthr.log";

					open(INPUT, $file) || die("$! Failed to open $file\n");
					while (<INPUT>) {
						my $line = $_;

						if ($line =~ /[+-]?(\d+\.\d+|\d+\.|\.\d+)/) {
							push @{$self->{_ResultData}}, [ "$wl-$type-$nthr", $iter, $1 ];
						}
					}
					close INPUT;
				}
			}
		}
	}

	my @ops;
	foreach my $type (@locktypes) {
		foreach my $wl (@workloads) {
			foreach my $nthr (@threads) {
				push @ops, "$wl-$type-$nthr"
			}
		}
	}
	$self->{_Operations} = \@ops;
}
