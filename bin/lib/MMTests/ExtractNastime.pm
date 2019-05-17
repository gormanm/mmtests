# ExtractNastime.pm
package MMTests::ExtractNastime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractNastime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	$reportDir =~ s/mpitime/mpi/;
	$reportDir =~ s/omptime/omp/;
	$reportDir =~ s/mpi-([a-z][a-z])time/mpi-\1/;
	$reportDir =~ s/omp-([a-z][a-z])time/omp-\1/;

	my @files = <$reportDir/*.log.1>;
	my @kernels;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		$split[-1] =~ s/.log.1//;
		push @kernels, $split[-1];
	}

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
