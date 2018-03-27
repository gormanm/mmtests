# ExtractNastime.pm
package MMTests::ExtractNastime;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;


sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractNastime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	$reportDir =~ s/mpitime/mpi/;
	$reportDir =~ s/omptime/omp/;

	my @files = <$reportDir/$profile/*.time>;
	my @kernels;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		$split[-1] =~ s/.time//;
		push @kernels, $split[-1];
	}

	die("No data") if $kernels[0] eq "";

	foreach my $kernel (@kernels) {
		my $file = "$reportDir/$profile/$kernel.time";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			push @{$self->{_ResultData}}, [ "sys-$kernel", $self->_time_to_sys($_) ];
		}
		close(INPUT);
	}
	foreach my $kernel (@kernels) {
		my $file = "$reportDir/$profile/$kernel.time";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			push @{$self->{_ResultData}}, [ "elspd-$kernel", $self->_time_to_elapsed($_) ];
		}
		close(INPUT);
	}

}

1;
