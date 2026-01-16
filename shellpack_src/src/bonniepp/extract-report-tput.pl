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

	if ($elements[9] > 0) {
		print "SeqOut char\t_\t_\t1\t$elements[9]\t_\n"
	}
	if ($elements[11] > 0) {
		print "SeqOut block\t_\t_\t1\t$elements[11]\tR\n"
	}
	if ($elements[13] > 0) {
		print "SeqOut rewrite\t_\t_\t1\t$elements[13]\t_\n"
	}
	if ($elements[15] > 0) {
		print "SeqIn char\t_\t_\t1\t$elements[15]\t_\n"
	}
	if ($elements[17] > 0) {
		print "SeqIn block\t_\t_\t1\t$elements[17]\t_\n"
	}
	if ($elements[19] > 0) {
		print "Random seeks\t_\t_\t1\t$elements[19]\t_\n"
	}
	if ($elements[26] > 0) {
		print "SeqCreate ops\t_\t_\t1\t$elements[26]\t_\n"
	}
	if ($elements[28] > 0) {
		print "SeqCreate read\t_\t_\t1\t$elements[28]\t_\n"
	}
	if ($elements[30] > 0) {
		print "SeqCreate del\t_\t_\t1\t$elements[30]\t_\n"
	}
	if ($elements[32] > 0) {
		print "RandCreate ops\t_\t_\t1\t$elements[32]\t_\n"
	}
	if ($elements[34] > 0) {
		print "RandCreate read\t_\t_\t1\t$elements[34]\t_\n"
	}
	if ($elements[36] > 0) {
		print "RandCreate del\t_\t_\t1\t$elements[36]\t_\n"
	}
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $file = "$reportDir/bonnie";

	my $input = open_log($file);
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

		extractNewFormat(@_, @elements);
	}
	close($input);
}

1;
