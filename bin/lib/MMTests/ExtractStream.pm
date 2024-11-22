# ExtractStream.pm
package MMTests::ExtractStream;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use MMTests::Stat;
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractStream";
	$self->{_PlotYaxis}  = DataTypes::LABEL_GBYTES_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "GB/sec";
	$self->{_PlotXaxis}  = "Operation";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($wallTime);
	my $dummy;
	my $copy = 0;
	my $scale = 0;
	my $add = 0;
	my $triad = 0;
	my $iterations = 0;
	my $nr_threads = "";

	foreach my $file (<$reportDir/stream-*.log>) {
		$iterations++;
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /Threads counted = ([0-9]+)/) {
				$nr_threads = $1;
			}
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

	$self->addData("copy-$nr_threads", 0, $copy / 1024 / $iterations );
	$self->addData("scale-$nr_threads", 0, $scale / 1024 / $iterations );
	$self->addData("add-$nr_threads", 0, $add / 1024  / $iterations );
	$self->addData("triad-$nr_threads", 0, $triad / 1024 / $iterations );
}

1;
