# ExtractKernbench.pm
package MMTests::ExtractKernbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_ModuleName} = "ExtractKernbench";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->{_RatioMatch} = "^elsp-.*";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tp, $name);
	my @threads;

	my @files = <$reportDir/$profile/kernbench-*-1.time>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-2];
		$thr =~ s/.log//;
		push @threads, $thr;
	}

	foreach my $nthr (@threads) {
		my @files = <$reportDir/$profile/kernbench-$nthr-*.time>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.time//;
			my $nr_samples = 0;

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /([0-9]):([0-9.]+)elapsed/) {
					push @{$self->{_ResultData}}, [ "user-$nthr", ++$nr_samples, $self->_time_to_user($line) ];
					push @{$self->{_ResultData}}, [ "syst-$nthr", ++$nr_samples, $self->_time_to_sys($line) ];
					push @{$self->{_ResultData}}, [ "elsp-$nthr", ++$nr_samples, $self->_time_to_elapsed($line) ];
				}
			}
			close INPUT;
		}

	}

	my @ops;
	foreach my $type ("user", "syst", "elsp") {
		foreach my $thread (sort {$a <=> $b} @threads) {
			push @ops, "$type-$thread";
		}
	}
	$self->{_Operations} = \@ops;
}
