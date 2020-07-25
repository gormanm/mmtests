# ExtractSpecfem3d.pm
package MMTests::ExtractSpecfem3d;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractSpecfem3d";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	my @files = <$reportDir/specfem3d-time.*>;
	my @stages;
	foreach my $file (@files) {
		my $stage = $file;
		$stage =~ s/.*specfem3d-time.//;
		$self->parse_time_all($file, $stage, ++$iteration);
		push @stages, $stage;
	}

	my @ratioops;
	foreach my $stage (@stages) {
		push @ratioops, "elsp-$stage";
	}
	$self->{_RatioOperations} = \@ratioops;
}
