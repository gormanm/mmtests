# ExtractHpcc.pm
package MMTests::ExtractHpcc;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractHpcc";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	foreach my $file (<$reportDir/time-*>) {
		my $nr_samples = 0;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			$self->addData("Elapsed", ++$nr_samples, $self->_time_to_elapsed($_));
		}
		close(INPUT);
	}
}

1;
