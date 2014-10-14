# ExtractFfsb.pm
package MMTests::ExtractFfsb;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractFfsb",
		_DataType    => MMTests::Extract::DATA_ACTIONS_PER_SECOND,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $reading_totals = 0;

	my $file = "$reportDir/noprofile/ffsb.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /Total Results/) {
			$reading_totals++;
			next;
		}

		if ($reading_totals == 1 && $line =~ /:/) {
			my ($dA, $oper, $dB, $dC, $ops, $dD) = split(/\s+/, $line);
			push @{$self->{_ResultData}}, [ $oper, $ops ];
		}
		if ($reading_totals == 1 && $line =~ /^-/) {
			$reading_totals = 2;
		}
		if ($reading_totals == 2 && $line =~ /([0-9.]+) Transactions per Second/) {
			push @{$self->{_ResultData}}, [ "Trans/sec", $1 ];
		}
		if ($reading_totals == 2 && $line =~ /Read Throughput: ([0-9.]+)MB\/sec/) {
			push @{$self->{_ResultData}}, [ "ReadMB/sec", $1 ];
		}
		if ($reading_totals == 2 && $line =~ /Write Throughput: ([0-9.]+)MB\/sec/) {
			push @{$self->{_ResultData}}, [ "WriteMB/sec", $1 ];
			$reading_totals = 0;
		}
	}
	close INPUT;
}

1;
