# ExtractDbt2install.pm
package MMTests::ExtractDbt2install;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractDbt2install";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_FieldLength} = 12;
	$self->{_RatioOperations} = [ "Elapsed" ];

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	open (INPUT, "$reportDir/time-install.log") ||
		die("Failed to open $reportDir/time-install.log");
	while (<INPUT>) {
		next if $_ !~ /elapsed/;
		$self->addData("Sys", 0, $self->_time_to_sys($_));
		$self->addData("Elapsed", 0, $self->_time_to_elapsed($_));
	}
}

1;
