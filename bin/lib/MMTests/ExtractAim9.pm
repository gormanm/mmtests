# ExtractAim9.pm
package MMTests::ExtractAim9;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use List::MoreUtils qw(uniq);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractAim9";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @operations_parse = ("page_test", "brk_test", "exec_test", "fork_test", "disk_cp", "disk_rd", "disk_rr", "disk_rw", "disk_src", "disk_wrt");
	my %operations_seen;

	# Multiple reads of the same file, don't really care as this is hardly
	# performance critical code.
	my @files = <$reportDir/aim9-*>;
	foreach my $workload (@operations_parse) {
		my $iteration = 0;
		foreach my $file (@files) {
			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				if ($_ =~ /$workload/) {
					my @elements = split(/\s+/, $_);
					$self->addData($workload, ++$iteration, $elements[6]);
					$operations_seen{$workload} = 1;
				}
			}
			close($input);
		}
	}

	my @operations;
	foreach my $workload (sort keys %operations_seen) {
		push @operations, $workload;
	}

	$self->{_Operations} = \@operations;
}

1;
