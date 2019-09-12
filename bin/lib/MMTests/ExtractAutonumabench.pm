# ExtractAutonumabench.pm
package MMTests::ExtractAutonumabench;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractAutonumabench";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_Opname}     = "Time";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @jobs = $self->discover_scaling_parameters($reportDir, "autonumabench-", "-1.time");

	foreach my $job (@jobs) {
		my @files = <$reportDir/autonumabench-$job-*.time>;
		my $iteration = 0;

		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("syst-$job", $iteration, $self->_time_to_sys($_));
			}
		}
	}

	foreach my $job (@jobs) {
		my @files = <$reportDir/autonumabench-$job-*.time>;
		my $iteration = 0;

		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("elsp-$job", $iteration, $self->_time_to_elapsed($_));
			}
		}
	}


	my @ratioops;
	foreach my $job (@jobs) {
		push @ratioops, "elsp-$job";
	}
	$self->{_RatioOperations} = \@ratioops;
}

1;
