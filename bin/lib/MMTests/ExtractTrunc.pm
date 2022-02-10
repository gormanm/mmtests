# ExtractTrunc.pm
package MMTests::ExtractTrunc;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractTrunc";
	$self->{_DataType}   = DataTypes::DATA_TIME_MSECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @files = <$reportDir/trunc-*.time>;
	my $iteration = 0;

	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			$self->addData("elapsed", ++$iteration, $self->_time_to_sys($_) * 1000);
		}
		close(INPUT);
	}
}
