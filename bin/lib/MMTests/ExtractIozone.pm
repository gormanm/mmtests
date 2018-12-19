# ExtractIozone.pm
package MMTests::ExtractIozone;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractIozone";
	$self->{_DataType}   = DataTypes::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($reportDir, $testName);
}


my %loadindex = (
	"SeqWrite"	=> 3,
	"Rewrite"	=> 4,
	"SeqRead"	=> 5,
	"Reread"	=> 6,
	"RandRead"	=> 7,
	"RandWrite"	=> 8,
	"BackRead"	=> 9
);

sub testcompare() {
	my ($opa, $sizea, $blksizea) = split /-/, @{$a}[0];
	my ($opb, $sizeb, $blksizeb) = split /-/, @{$b}[0];
	if ($opa ne $opb) {
		return $loadindex{$opa} <=> $loadindex{$opb};
	}
	if ($sizea != $sizeb) {
		return $sizea <=> $sizeb;
	}
	return $blksizea <=> $blksizeb;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @sizes;
	my %sizesSeen;
	my @files = <$reportDir/$profile/iozone-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		my $iteration = $split[-1];
		open(INPUT, $file) || die("Failed to open $file\n");

		# Skip headings
		while (<INPUT>) {
			if ($_ =~ /^\s+kB\s+reclen\s+/) {
				last;
			}
		}
		while (<INPUT>) {
			if ($_ eq "\n") {
				last;
			}
			my @elements = split(/\s+/, $_);
			my $size = $elements[1];
			my $blksize = $elements[2];

			foreach my $op (sort keys(%loadindex)) {
				$self->addData("$op-$size-$blksize", $iteration, $elements[$loadindex{$op}]);
				if ($sizesSeen{"$size-$blksize"} != 1) {
					push @sizes, "$size-$blksize";
					$sizesSeen{"$size-$blksize"} = 1;
				}
			}
		}
		close INPUT;
	}

	my @ops;
	foreach my $opName ("SeqWrite", "Rewrite", "SeqRead", "Reread", "RandRead", "RandWrite", "BackRead") {
		foreach my $size (@sizes) {
			push @ops, "$opName-$size";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
