# ExtractFrontistr.pm
package MMTests::ExtractFrontistr;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractFrontistr";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->SUPER::initialise($subHeading);
}
sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	# Get domains parameter
	open (INPUT, "$reportDir/scaling-parameters");
	my $line = <INPUT>;
	my ($name, $dummy, $mpi, $dummy, $omp) = split(/\s+/, $line);
	close INPUT;

	my @files = <$reportDir/frontistr-time.*>;
	foreach my $file (@files) {
		$self->parse_time_all($file, "$name", ++$iteration);
	}

	my @ratioops;
	push @ratioops, "elsp-$name";
	$self->{_RatioOperations} = \@ratioops;
}
