# ExtractNas.pm
package MMTests::ExtractXsbench;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use MMTests::Stat;
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractXsbench";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_Opname}     = "Lookups/Sec";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @threads = $self->discover_scaling_parameters($reportDir, "xsbench-", "-1.log.gz");

	die("No data") if $threads[0] eq "";

	foreach my $nr_threads (@threads) {
		my $nr_samples = 0;

		foreach my $file (<$reportDir/xsbench-$nr_threads-*.log.gz>) {
			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;
				if ($line =~ /^Lookups\/s:\s+([0-9,]+)/) {
					my $lookups = $1;
					$lookups =~ s/,//g;
					$self->addData($nr_threads, ++$nr_samples, $lookups);
					last;
				}
			}
			close $input;
		}
	}
}

1;
