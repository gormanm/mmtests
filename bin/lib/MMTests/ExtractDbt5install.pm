# ExtractDbt5install.pm
package MMTests::ExtractDbt5install;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractDbt5install";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	open (INPUT, "$reportDir/noprofile/time-install.log") ||
		die("Failed to open $reportDir/noprofile/time-install.log");
	while (<INPUT>) {
		next if $_ !~ /elapsed/;
		push @{$self->{_ResultData}}, [ "Sys",     $self->_time_to_sys($_) ];
		push @{$self->{_ResultData}}, [ "Elapsed", $self->_time_to_elapsed($_) ];
	}
	$self->{_Operations} = [ "Sys", "Elapsed"];
}

1;
