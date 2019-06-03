# ExtractBonnietput.pm
package MMTests::ExtractBonnietput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractBonnietput";
	$self->{_DataType}   = DataTypes::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_DefaultPlot} = "SeqOut Block";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $file = "$reportDir/bonnie";
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
			$self->addData("SeqOut Char", 0, $elements[2]);
		}
		if ($elements[4] != 0) {
			$self->addData("SeqOut Block", 0, $elements[4]);
		}
		if ($elements[6] != 0) {
			$self->addData("SeqOut Rewrite", 0, $elements[6]);
		}
		if ($elements[8] != 0) {
			$self->addData("SeqIn Char", 0, $elements[8]);
		}
		if ($elements[10] != 0) {
			$self->addData("SeqIn Block", 0, $elements[10]);
		}
		if ($elements[12] != 0) {
			$self->addData("Random seeks", 0, $elements[12]);
		}
		if ($elements[15] != 0) {
			$self->addData("SeqCreate ops", 0, $elements[15]);
		}
		if ($elements[17] != 0) {
			$self->addData("SeqCreate read", 0, $elements[17]);
		}
		if ($elements[19] != 0) {
			$self->addData("SeqCreate del", 0, $elements[19]);
		}
		if ($elements[21] != 0) {
			$self->addData("RandCreate ops", 0, $elements[21]);
		}
		if ($elements[23] != 0) {
			$self->addData("RandCreate read", 0, $elements[23]);
		}
		if ($elements[25] != 0) {
			$self->addData("RandCreate del", 0, $elements[25]);
		}
	}
	close INPUT;
}

1;
