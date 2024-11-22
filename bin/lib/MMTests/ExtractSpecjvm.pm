# ExtractSpecjvm.pm
package MMTests::ExtractSpecjvm;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSpecjvm";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_MINUTE;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "histogram";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $pagesize = "base";

	if (! -e "$reportDir/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/$pagesize") {
		$pagesize = "default";
	}

	my @files = <$reportDir/$pagesize/SPECjvm2008.*/SPECjvm2008.*.txt>;
	foreach my $file (@files) {
		my $section = 0;
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;

			if ($line =~ /======================/) {
				$section++;
				next;
			}

			if ($section == 4 && $line =~ /iteration [0-9]+/) {
				my ($bench, $dA, $dB, $dC, $dD, $dE, $ops) = split(/\s+/, $line);
				if ($bench !~ /startup/) {
					$self->addData($bench, 0, $ops);
				}
			}
		}
	}
	close INPUT;
}

1;
