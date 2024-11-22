# ExtractScimarkc.pm
package MMTests::ExtractScimarkc;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractScimarkc";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_MINUTE;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "histogram";
	$self->{_ClientSubheading} = 1;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/scimarkc.*>) {
		open(INPUT, $file) || die("Failed to open $file\n");
		$iteration++;
		while (<INPUT>) {
			my $line = $_;
			next if $line !~ /Mflops:/;

			my @elements = split(/\s+/, $line);
			$elements[0] =~ s/ /_/;

			$self->addData("$elements[0]", $iteration, $elements[2]);
		}
		close(INPUT);
	}
}

1;
