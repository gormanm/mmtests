# ExtractSpeccpu.pm
package MMTests::ExtractSpeccpu2017;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSpeccpu2017";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $section = 0;

	foreach my $file (<$reportDir/CPU2017.001.*.txt>) {
		open(INPUT, $file) || next;
		my $reading = 0;

		while (<INPUT>) {
			my $line = $_;

			if ($line =~ /======================/) {
				$reading = 1;
				next;
			}
			if ($line =~ /Est. SPEC/ || $line !~ /^[0-9]/) {
				$reading = 0;
			}

			if (!$reading) {
				next;
			}
			my @elements = split(/\s+/, $line);
			my $bench = $elements[0];
			my $ops = $elements[2];

			if ($file =~ /[0-9]\.int/) {
				$bench .= ".int";
			} else {
				$bench .= ".fp";
			}

			if ($ops ne "") {
				$self->addData($bench, 0, $ops);
			}
		}
	}
	close INPUT;
}

1;
