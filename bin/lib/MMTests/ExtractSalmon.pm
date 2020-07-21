# ExtractSalmon.pm
package MMTests::ExtractSalmon;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractSalmon";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	# Get domains parameter
	open (INPUT, "$reportDir/scaling-parameters");
	my $line = <INPUT>;
	my @elements = split(/\s+/, $line);
	my $subdomains = $elements[0];

	my @files = <$reportDir/salmon-time.*>;
	foreach my $file (@files) {
		$self->parse_time_all($file, $subdomains, ++$iteration);
	}

	my @ratioops;
	push @ratioops, "elsp-$subdomains";
	$self->{_RatioOperations} = \@ratioops;
}
