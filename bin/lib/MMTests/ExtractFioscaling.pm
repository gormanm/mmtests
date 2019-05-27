# ExtractFioscaling
package MMTests::ExtractFioscaling;
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
	my $jobs = 0;
	my $rw = 0;

	$file = "$reportDir/$worker.gz";

	open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
	while (<INPUT>) {
		if ( /^fio/ ) {
			# fio command line, parse for number of jobs
			my @words;
			@words = split(' ');
			foreach my $word (@words) {
				if ($word =~ m/^--numjobs=/) {
					$word =~ s/--numjobs=//;
					$jobs=$word
				}
			}
		} elsif ( /^[5;fio]/ ) {
			# assume fio terse format version 3
			my @elements;

			@elements = split(/;/, $_);
			# Total read KB > 0?
			if ($elements[5] > 0) {
				$self->addData("$worker-read", $jobs, $elements[44]);
				$rw = $rw | 1;
			}
			# Total written KB > 0?
			if ($elements[52] > 0) {
				$self->addData("$worker-write", $jobs, $elements[91]);
				$rw = $rw | 2;
			}
		}
	}
	close INPUT;
	return $rw;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @file_types = ('read', 'write', 'rw', 'randread', 'randwrite', 'randrw');
	my @ops;
	my $worker;
	my $rw = 0;

	for my $type (@file_types) {
		$worker = "fio-scaling-$type";
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
