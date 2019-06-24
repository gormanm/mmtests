# ExtractFioscaling
package MMTests::ExtractFiossd;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractFio";
	$self->{_DataType}   = DataTypes::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($subHeading);
}

sub extractOneFile {
	my ($self, $reportDir, $worker) = @_;
	my $file;
	my $size = 0;
	my $rw = 0;

	$file = "$reportDir/$worker";

	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file\n");
	} else {
		open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz\n");
	}
	while (<INPUT>) {
		if ( /^fio/ ) {
			# fio command line, parse for size, e.g. --size=1G
			my @words;
			@words = split(' ');
			foreach my $word (@words) {
				if ($word =~ m/^--size=/) {
					$word =~ s/--size=//;
					$size=$word
				}
			}
		} elsif ( /^[5;fio]/ ) {
			# assume fio terse format version 5
			my @elements;

			@elements = split(/;/, $_);
			# Total read KB > 0?
			if ($elements[5] > 0) {
				$self->addData("$worker-read", $size, $elements[44]);
				$rw = $rw | 1;
			}
			# Total written KB > 0?
			if ($elements[52] > 0) {
				$self->addData("$worker-write", $size, $elements[91]);
				$rw = $rw | 2;
			}
		}
	}
	close INPUT;
	return $rw;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @file_types = ('rand-jobs_1-qd_1-bs_4k', 'rand-jobs_4-qd_32-bs_4k',
			  'seq-jobs_1-qd_2-bs_128k', 'seq-jobs_1-qd_4-bs_128k');
	my @ops;
	my $worker;
	my $rw = 0;

	for my $type (@file_types) {
		$worker = "fio-ssd-$type";
		$rw = extractOneFile(@_, $worker);
		if ($rw & 1) {
			push @ops, "$worker-read";
		}
		if ($rw & 2) {
			push @ops, "$worker-write";
		}
	}

	$self->{_Operations} = \@ops;
}

1;
