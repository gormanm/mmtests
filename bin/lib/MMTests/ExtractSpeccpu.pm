# ExtractSpeccpu.pm
package MMTests::ExtractSpeccpu;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSpeccpu";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $section = 0;
	my $pagesize = "base";

	if (! -e "$reportDir/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/$pagesize") {
		$pagesize = "default";
	}

	my $size = "test";
	if (! -e "$reportDir/$pagesize/CINT2006.001.test.txt") {
		$size = "ref";
	}

	foreach my $file ("$reportDir/$pagesize/CINT2006.001.$size.txt", "$reportDir/$pagesize/CFP2006.001.$size.txt") {
		open(INPUT, $file) || die("Failed to open $file\n");
		my $reading = 0;

		while (<INPUT>) {
			my $line = $_;

			if ($line =~ /======================/) {
				$reading = 1;
				next;
			}
			if ($line =~ /Est. SPEC/) {
				$reading = 0;
			}

			if (!$reading) {
				next;
			}
			my @elements = split(/\s+/, $line);
			my $bench = $elements[0];
			my $ops = $elements[2];

			if ($file =~ /CINT/) {
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
