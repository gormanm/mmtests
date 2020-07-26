# ExtractWrf.pm
package MMTests::ExtractWrf;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractWrf";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	my @models;
	my @files = <$reportDir/wrf-time.*>;
	foreach my $file (@files) {
		my $model = $file;
		$model =~ s/.*wrf-time.//;
		$self->parse_time_all($file, $model, ++$iteration);
		push @models, $model;
	}

	my @ratioops;
	foreach my $model (@models) {
		push @ratioops, "elsp-$model";
	}
	$self->{_RatioOperations} = \@ratioops;
}
