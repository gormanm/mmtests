# ExtractParsec.pm
package MMTests::ExtractParsec;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractParsec";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->{_RatioOperations} = [ "elsp" ];
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/time.*>) {
		$self->parse_time_all($file, -1, ++$iteration);
	}
}
