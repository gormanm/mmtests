# ExtractMicrotput.pm
package MMTests::ExtractMicrotput;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractMicrotput";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "group-errorlines";
	$self->{_Precision} = 4;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @threads = $self->discover_scaling_parameters($reportDir, "microtput-", "-1");

	foreach my $thread (@threads) {
		my $nr_samples = 0;
		foreach my $file (<$reportDir/microtput-$thread-*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				if ($_ =~ /throughput:\s*([0-9.]*)/) {
					$self->addData($thread, ++$nr_samples, $1);
				}
			}
			close INPUT;
		}
	}
}
1;
