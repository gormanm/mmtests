# ExtractFfsb.pm
package MMTests::ExtractFfsb;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFfsb";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TRANS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Trans/sec";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $reading_totals = 0;

	my $input = $self->SUPER::open_log("$reportDir/ffsb.log");
	while (<$input>) {
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
	close $input;
}

1;
