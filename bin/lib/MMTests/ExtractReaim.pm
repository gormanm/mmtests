# ExtractReaim.pm
package MMTests::ExtractReaim;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractReaim";
	$self->{_DataType}   = DataTypes::DATA_ACTIONS_PER_MINUTE;
	$self->{_PlotType}   = "process-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $required_heading = "JPM";

	my @workfiles = <$reportDir/workfile.*>;
	foreach my $workfile (@workfiles) {
		my $worktitle = $workfile;
		$worktitle =~ s/.*\.//;

		my @files = <$workfile/reaim.*.csv>;
		my $iteration = 0;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");

			# Read the header and find the appropriate field
			my @elements = split(/,/, <INPUT>);
			my $index = -1;
			foreach my $element (@elements) {
				$index++;
				if ($element eq $required_heading) {
					last;
				}
			}

			$iteration++;
			while (<INPUT>) {
				my $line = $_;
				@elements = split(/,/, $line);
				$self->addData("$worktitle-$elements[0]", $iteration, $elements[$index]);
				if ($iteration == 1) {
					push @{$self->{_Operations}}, "$worktitle-$elements[0]";
				}
			}
			close INPUT;
		}
	}
}

1;
