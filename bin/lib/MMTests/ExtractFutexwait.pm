# ExtractFutexwait.pm
package MMTests::ExtractFutexwait;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractFutexwait";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @threads = $self->discover_scaling_parameters($reportDir, "futexwait-", "-1.log");;
	foreach my $nthr (@threads) {
		my @files = <$reportDir/futexwait-$nthr-*.log>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $nr_samples = 0;

			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;
				if ($line =~ /Result: ([0-9]+) Kiter\/s/) {
					$self->addData($nthr, ++$nr_samples, $1);
				}
			}
			close $input;
		}
	}
}

1;
