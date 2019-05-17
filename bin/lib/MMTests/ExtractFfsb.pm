# ExtractFfsb.pm
package MMTests::ExtractFfsb;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFfsb";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Trans/sec";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $reading_totals = 0;

	my $file = "$reportDir/ffsb.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /Total Results/) {
			$reading_totals++;
			next;
		}

		if ($reading_totals == 1 && $line =~ /:/) {
			my ($dA, $oper, $dB, $dC, $ops, $dD) = split(/\s+/, $line);
			$self->addData($oper, 0, $ops);
		}
		if ($reading_totals == 1 && $line =~ /^-/) {
			$reading_totals = 2;
		}
		if ($reading_totals == 2 && $line =~ /([0-9.]+) Transactions per Second/) {
			$self->addData("Trans/sec", 0, $1 );
		}
		if ($reading_totals == 2 && $line =~ /Read Throughput: ([0-9.]+)MB\/sec/) {
			$self->addData("ReadMB/sec", 0, $1 );
		}
		if ($reading_totals == 2 && $line =~ /Write Throughput: ([0-9.]+)MB\/sec/) {
			$self->addData("WriteMB/sec", 0, $1 );
			$reading_totals = 0;
		}
	}
	close INPUT;
}

1;
