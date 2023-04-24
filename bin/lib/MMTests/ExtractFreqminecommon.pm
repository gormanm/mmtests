# ExtractFreqmine.pm
package MMTests::ExtractFreqminecommon;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->SUPER::initialise($subHeading);

	$self->{_ModuleName} = "ExtractFreqmine";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "thread-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @threads = $self->discover_scaling_parameters($reportDir, "freqmine-", "-1.log");

	foreach my $nthr (@threads) {
		my @files = <$reportDir/freqmine-$nthr-*.log>;

		foreach my $file (@files) {
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $nr_samples = 0;

			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;
				if ($line =~ /cost ([0-9.]+) seconds, the FPgrowth cost ([0-9.]+) seconds/) {
					my $tottime = $1 + $2;
					$self->addData($nthr, ++$nr_samples, $tottime);
				}
			}
			close $input;
		}

	}
}
