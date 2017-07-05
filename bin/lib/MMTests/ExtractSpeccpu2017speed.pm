# ExtractSpeccpu.pm
package MMTests::ExtractSpeccpu2017speed;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSpeccpu2017speed";
	$self->{_DataType}   = DataTypes::DATA_RATIO_SPEEDUP;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $section = 0;

	my $size = "test";
	if (! -e "$reportDir/$profile/CPU2017.001.fpspeed.test.txt") {
		$size = "ref";
	}

	foreach my $file ("$reportDir/$profile/CPU2017.001.intspeed.$size.txt", "$reportDir/$profile/CPU2017.001.fpspeed.$size.txt") {
		open(INPUT, $file) || die("Failed to open $file\n");
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
				push @{$self->{_ResultData}}, [ $bench, $ops ];
			}
		}
	}
	close INPUT;
}

1;
