package MMTests::ExtractBonniepptput;
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

sub extractOldFormat {
	my ($self, $reportDir, @elements) = @_;

	# element breakdown version 1.03e
	#  0 hostname				 1 chunk size
	#  2 seq output char    tput		 3 seq output char    cpu
	#  4 seq output block   tput		 5 seq output block   cpu
	#  6 seq output rewrite tput		 7 seq output rewrite cpu
	#  8 seq input  char    tput		 9 seq input  char    cpu
	# 10 seq input  block   tput		11 seq input  block   cpu
	# 12 random seeks       ops/sec		13 random seeks       cpu
	# 14 num files parameter
	# 15 seq create         ops/sec		16 seq create         cpu
	# 17 seq create read    ops/sec		18 seq create read    cpu
	# 19 seq create delete  ops/sec		20 seq create delete  cpu
	# 21 random create      ops/sec		22 random create      cpu
	# 23 random create read ops/sec		24 random create read cpu
	# 25 random create dele ops/sec		26 random create dele cpu

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

sub extractNewFormat {
	my ($self, $reportDir, @elements) = @_;

	# element breakdown version 1.98
	#  0 format version		 1 bonnie version	   2 hostname
	#  3 concurrency		 4 seed			   5 file size
	#  6 chunk size			 7 seeks		   8 seek_proc_count
	#  9 seq output char    tput	10 seq output char    cpu
	# 11 seq output block   tput	12 seq output block   cpu
	# 13 seq output rewrite tput	14 seq output rewrite cpu
	# 15 seq input  char    tput	16 seq input  char    cpu
	# 17 seq input  block   tput	18 seq input  block   cpu
	# 19 random seeks       ops/sec	20 random seeks       cpu
	# 21 num files parameter	22 max_size		  23 min_size
	# 24 num_dirs			25 file_chunk_size
	# 26 seq create         ops/sec	27 seq create         cpu
	# 28 seq create read    ops/sec	29 seq create read    cpu
	# 30 seq create delete  ops/sec	31 seq create delete  cpu
	# 32 random create      ops/sec	33 random create      cpu
	# 34 random create read ops/sec	35 random create read cpu
	# 36 random create dele ops/sec	37 random create dele cpu
	# 38 char write latency		39 block write latency	  40 rw latency
	# 41 char read latency		42 block read latency	  43 seek latency
	# 44 seq create latency		45 seq stat lat		  46 seq del lat
	# 47 random create latency	48 random stat lat	  49 random del lat

	if ($elements[9] != 0) {
		$self->addData("SeqOut Char", 0, $elements[9]);
	}
	if ($elements[11] != 0) {
		$self->addData("SeqOut Block", 0, $elements[11]);
	}
	if ($elements[13] != 0) {
		$self->addData("SeqOut Rewrite", 0, $elements[13]);
	}
	if ($elements[15] != 0) {
		$self->addData("SeqIn Char", 0, $elements[15]);
	}
	if ($elements[17] != 0) {
		$self->addData("SeqIn Block", 0, $elements[17]);
	}
	if ($elements[19] != 0) {
		$self->addData("Random seeks", 0, $elements[19]);
	}
	if ($elements[26] != 0) {
		$self->addData("SeqCreate ops", 0, $elements[26]);
	}
	if ($elements[28] != 0) {
		$self->addData("SeqCreate read", 0, $elements[28]);
	}
	if ($elements[30] != 0) {
		$self->addData("SeqCreate del", 0, $elements[30]);
	}
	if ($elements[32] != 0) {
		$self->addData("RandCreate ops", 0, $elements[32]);
	}
	if ($elements[34] != 0) {
		$self->addData("RandCreate read", 0, $elements[34]);
	}
	if ($elements[36] != 0) {
		$self->addData("RandCreate del", 0, $elements[36]);
	}
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $file = "$reportDir/bonnie";

	if (! -e "$file" && ! -e "$file.gz") {
		$file =~ s/bonnie\/logs/bonniepp\/logs/;
	}

	my $input = $self->SUPER::open_log("$file");
	while (<$input>) {
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

		if ($elements[0] eq "1.98") {
			extractNewFormat(@_, @elements);
		} else {
			extractOldFormat(@_, @elements);
		}
	}
	close($input);
}

1;
