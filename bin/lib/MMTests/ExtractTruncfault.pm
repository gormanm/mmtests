# ExtractTruncfault.pm
package MMTests::ExtractTruncfault;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractTruncfault";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_MSECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @files = <$reportDir/fault-*.time>;
	my $iteration = 0;

	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			$self->addData("elapsed", ++$iteration, $self->_time_to_elapsed($_) * 1000);
		}
		close(INPUT);
	}
}
