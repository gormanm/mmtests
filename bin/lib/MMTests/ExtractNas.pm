# ExtractNas.pm
package MMTests::ExtractNas;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use MMTests::Stat;
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractNas";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_Opname}     = "Time";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @kernels = $self->discover_scaling_parameters($reportDir, "", ".log.1");

	die("No data") if $kernels[0] eq "";

	foreach my $kernel (@kernels) {
		my $nr_samples = 0;

		foreach my $file (<$reportDir/$kernel.log.*>) {
			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;
				if ($line =~ /\s+Time in seconds =\s+([0-9.]+)/) {
					$self->addData($kernel, ++$nr_samples, $1);
					last;
				}
			}
			close $input;
		}
	}
}

1;
