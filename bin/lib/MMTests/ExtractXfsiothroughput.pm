# ExtractXfsiothroughput.pm
package MMTests::ExtractXfsiothroughput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractXfsiothroughput";
	$self->{_PlotYaxis}  = DataTypes::LABEL_MBYTES_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/*-log.*>) {
		my $testcase = $file;
		$testcase =~ s/.*\///;
		$testcase =~ s/-log.*//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $tput;

			if ($_ =~ /.*\(([0-9.]+) MiB\/sec.*/) {
				$tput = $1;
			} elsif ($_ =~ /.*\(([0-9.]+) GiB\/sec.*/) {
				$tput = $1 * 1024;
			} elsif ($_ =~ /.*\(([0-9.]+) KiB\/sec.*/) {
				$tput = $1 / 1024;
			} else {
				next;
			}

			$self->addData("$testcase-tput", ++$iteration, $tput);
		}
		close(INPUT);
	}
}

1;
