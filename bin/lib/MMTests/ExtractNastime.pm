# ExtractNastime.pm
package MMTests::ExtractNastime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractNastime";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @kernels = $self->discover_scaling_parameters($reportDir, "", ".log.1");

	foreach my $kernel (@kernels) {
		my $nr_samples = 0;

		foreach my $file (<$reportDir/time-$kernel.*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("sys-$kernel", ++$nr_samples, $self->_time_to_sys($_));
			}
			close(INPUT);
		}
	}

	foreach my $kernel (@kernels) {
		my $nr_samples = 0;

		foreach my $file (<$reportDir/time-$kernel.*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("elspd-$kernel", ++$nr_samples, $self->_time_to_elapsed($_));
			}
			close(INPUT);
		}
	}
}

1;
