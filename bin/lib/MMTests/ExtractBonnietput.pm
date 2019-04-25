# ExtractBonnietput.pm
package MMTests::ExtractBonnietput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractBonnietput";
	$self->{_DataType}   = DataTypes::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_DefaultPlot} = "SeqOut Block";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	$reportDir =~ s/bonnietput/bonnie/;
	my $recent = 0;

	my @files = <$reportDir/$profile/bonnie.*>;
	my $iteration = 1;
	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line !~ /^[a-z0-9.-]+,/) {
				next;
			}

			my @elements = split(/,/, $line);
			for (my $i = 0; $i <= $#elements; $i++) {
				if ($elements[$i] =~ /^\+/) {
					$elements[$i] = -1;
				}
			}

			# element breakdown
			# 0	hostname
			# 1	chunk size
			# 2	seq output char    tput
			# 3	seq output char    cpu
			# 4	seq output block   tput
			# 5	seq output block   cpu
			# 6	seq output rewrite tput
			# 7	seq output rewrite cpu
			# 8	seq input  char    tput
			# 9	seq input  char    cpu
			# 10	seq input  block   tput
			# 11	seq input  block   cpu
			# 12    random seeks       ops/sec
			# 13	random seeks       cpu
			# 14	num files parameter
			# 15    seq create         ops/sec
			# 16    seq create         cpu
			# 17    seq create read    ops/sec
			# 18	seq create read    cpu
			# 19    seq create delete  ops/sec
			# 20    seq create delete  cpu
			# 21    random create      ops/sec
			# 22    random create      cpu
			# 23    random create read ops/sec
			# 24    random create read cpu
			# 25    random create dele ops/sec
			# 26    random create dele cpu

			if ($elements[2] != 0) {
				$self->addData("SeqOut Char", $iteration, $elements[2]);
			}
			if ($elements[4] != 0) {
				$self->addData("SeqOut Block", $iteration, $elements[4]);
			}
			if ($elements[6] != 0) {
				$self->addData("SeqOut Rewrite", $iteration, $elements[6]);
			}
			if ($elements[8] != 0) {
				$self->addData("SeqIn Char", $iteration, $elements[8]);
			}
			if ($elements[10] != 0) {
				$self->addData("SeqIn Block", $iteration, $elements[10]);
			}
			if ($elements[12] != 0) {
				$self->addData("Random seeks", $iteration, $elements[12]);
			}
			if ($elements[15] != 0) {
				$self->addData("SeqCreate ops", $iteration, $elements[15]);
			}
			if ($elements[17] != 0) {
				$self->addData("SeqCreate read", $iteration, $elements[17]);
			}
			if ($elements[19] != 0) {
				$self->addData("SeqCreate del", $iteration, $elements[19]);
			}
			if ($elements[21] != 0) {
				$self->addData("RandCreate ops", $iteration, $elements[21]);
			}
			if ($elements[23] != 0) {
				$self->addData("RandCreate read", $iteration, $elements[23]);
			}
			if ($elements[25] != 0) {
				$self->addData("RandCreate del", $iteration, $elements[25]);
			}

			$iteration++;
		}
		close INPUT;
	}
}

1;
