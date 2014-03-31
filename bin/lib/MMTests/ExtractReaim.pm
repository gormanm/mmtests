# ExtractReaim.pm
package MMTests::ExtractReaim;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractReaim",
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
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Children", "Workfile", "Jobs/minute" ];
	$self->{_TestName} = $testName;
	$self->{_SummariseColumn} = 1;
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @children = @{$self->{_Children}};
	my @worktitles = @{$self->{_Worktitles}};
	my $fieldLength = $self->{_FieldLength};
	my $column = 1;

	foreach my $worktitle (@worktitles) {
		foreach my $child (@children) {
			my @units;
			my @row;
			foreach my $row (@{$data[$child]}) {
				if (@${row}[0] eq $worktitle) {
					push @units, @{$row}[$column];
				}
			}
			push @row, "$worktitle-$child";
			foreach my $funcName ("calc_min", "calc_mean", "calc_true_mean", "calc_stddev", "calc_max") {
				no strict "refs";
				push @row, &$funcName(@units);
			}
			push @{$self->{_SummaryData}}, \@row;
		}
	}
	return 1;
}


sub printReport() {
        my ($self, $reportDir) = @_;
        my @children = @{$self->{_Children}};

        $self->_printClientReport($reportDir, @children);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $required_heading = "JPM";
	my $first = 1;
	my @children;
	my @worktitles;

	my @workfiles = <$reportDir/noprofile/workfile.*>;
	foreach my $workfile (@workfiles) {
		my $worktitle = $workfile;
		$worktitle =~ s/.*\.//;
		push @worktitles, $worktitle;

		my @files = <$workfile/reaim.*.csv>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");

			# Read the header and find the appropriate field
			my @elements = split(/,/, <INPUT>);
			my $index = -1;
			foreach my $element (@elements) {
				$index++;
				if ($element eq $required_heading) {
					last;
				}
			}
		
			while (<INPUT>) {
				my $line = $_;
				@elements = split(/,/, $line);
				push @{$self->{_ResultData}[$elements[0]]}, [ $worktitle, $elements[$index] ];
				if ($first) {
					push @children, $elements[0];
				}
			}
			close INPUT;
			$first = 0;
		}
	}

	$self->{_Children} = \@children;
	$self->{_Worktitles} = \@worktitles;
}

1;
