# ExtractStream.pm
package MMTests::ExtractStream;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use MMTests::Stat;
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractStream";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "MB/sec";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($wallTime);
	my $dummy;
	my $copy = 0;
	my $scale = 0;
	my $add = 0;
	my $triad = 0;
	my $iterations = 0;

	foreach my $file (<$reportDir/$profile/stream-*.log>) {
		$iterations++;
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /^Copy:\s+([0-9.]*)\s.*/) {
				$copy += $1;
			}
			if ($line =~ /^Scale:\s+([0-9.]*)\s.*/) {
				$scale += $1;
			}
			if ($line =~ /^Add:\s+([0-9.]*)\s.*/) {
				$add += $1;
			}
			if ($line =~ /^Triad:\s+([0-9.]*)\s.*/) {
				$triad += $1;
			}

		}
		close INPUT;
	}

	$self->addData("copy", 0, $copy  / $iterations );
	$self->addData("scale", 0, $scale / $iterations );
	$self->addData("add", 0, $add   / $iterations );
	$self->addData("triad", 0, $triad / $iterations );
}

1;
