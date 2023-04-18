# ExtractAim9.pm
package MMTests::ExtractAim9;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractAim9";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_Operations} = [ "page_test", "brk_test", "exec_test", "fork_test" ];

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	# Multiple reads of the same file, don't really care as this is hardly
	# performance critical code.
	my @files = <$reportDir/aim9-*>;
	foreach my $workload (@{$self->{_Operations}}) {
		my $iteration = 0;
		foreach my $file (@files) {
			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				if ($_ =~ /$workload/) {
					my @elements = split(/\s+/, $_);
					$self->addData($workload, ++$iteration, $elements[6]);
				}
			}
			close($input);
		}
	}
}

1;
