# ExtractNas.pm
package MMTests::ExtractNas;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use MMTests::Stat;
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
	my $class;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		$split[-1] =~ s/.log.1//;
		my $kernel = $split[-1];
		($kernel, $class) = split /\./, $kernel;
		push @kernels, $kernel;
	}

	die("No data") if $kernels[0] eq "";

	foreach my $kernel (@kernels) {
		my $nr_samples = 0;

		foreach my $file (<$reportDir/$profile/$kernel.$class.log.*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /\s+Time in seconds =\s+([0-9.]+)/) {
					$self->addData($kernel, ++$nr_samples, $1);
					last;
				}
			}
			close INPUT;
		}
	}

	$self->{_Operations} = \@kernels;
}

1;
