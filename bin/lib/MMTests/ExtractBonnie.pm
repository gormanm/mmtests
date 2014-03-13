# ExtractBonnie.pm
package MMTests::ExtractBonnie;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPostmark",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 16;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Op", "Sample" ];

	$self->{_SummaryLength} = 16;
	$self->{_SummaryHeaders} = [ "Op", "Min", "Mean", "Stddev", "Max" ];
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};

	foreach my $operation (@_operations) {
		my @units;
		my @row;
		my $iterations = 0;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
				$iterations++;
			}
		}
		push @row, $operation;
		foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@units);
		}
		push @{$self->{_SummaryData}}, \@row;

	}

	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $recent = 0;

	my @files = <$reportDir/noprofile/bonnie.*>;
	my $iteration = 1;
	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line !~ /^[a-z]+,/) {
				next;
			}

			my @elements = split(/,/, $line);

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

			push @{$self->{_ResultData}}, [ "SeqOut Char",     $iteration, $elements[2] ];
			push @{$self->{_ResultData}}, [ "SeqOut Block",    $iteration, $elements[4] ];
			push @{$self->{_ResultData}}, [ "SeqOut Rewrite",  $iteration, $elements[6] ];
			push @{$self->{_ResultData}}, [ "SeqIn  Char",     $iteration, $elements[8] ];
			push @{$self->{_ResultData}}, [ "SeqIn  Block",    $iteration, $elements[10] ];
			push @{$self->{_ResultData}}, [ "Random seeks",    $iteration, $elements[12] ];
			push @{$self->{_ResultData}}, [ "SeqCreate ops",   $iteration, $elements[15] ];
			push @{$self->{_ResultData}}, [ "SeqCreate read",  $iteration, $elements[17] ];
			push @{$self->{_ResultData}}, [ "SeqCreate del",   $iteration, $elements[19] ];
			push @{$self->{_ResultData}}, [ "RandCreate ops",  $iteration, $elements[21] ];
			push @{$self->{_ResultData}}, [ "RandCreate read", $iteration, $elements[23] ];
			push @{$self->{_ResultData}}, [ "RandCreate del",  $iteration, $elements[25] ];

			# Populate the operations table without cut and pasting the above block
			if ($iteration == 1) {
				my @operations;
				foreach my $row (@{$self->{_ResultData}}) {
					push @operations, @{$row}[0];
				}
				$self->{_Operations} = \@operations;
			}
			$iteration++;
		}
		close INPUT;
	}
}

1;
