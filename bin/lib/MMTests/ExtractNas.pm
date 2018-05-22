# ExtractNas.pm
package MMTests::ExtractNas;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use VMR::Stat;
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractNas";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_Opname}     = "Time";
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @files = <$reportDir/$profile/*.log.1>;
	my @kernels;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		$split[-1] =~ s/.log.1//;
		push @kernels, $split[-1];
	}

	die("No data") if $kernels[0] eq "";

	foreach my $kernel (@kernels) {
		my $nr_samples = 0;

		foreach my $file (<$reportDir/$profile/$kernel.log.*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /\s+Time in seconds =\s+([0-9.]+)/) {
					push @{$self->{_ResultData}}, [ $kernel, ++$nr_samples, $1 ];
					last;
				}
			}
			close INPUT;
		}
	}

	$self->{_Operations} = \@kernels;
}

1;
