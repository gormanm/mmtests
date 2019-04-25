# Monitor.pm
#
# This is base class description for modules that parse MM Tests directories
# and extract from the monitors

package MMTests::Monitor;

use MMTests::PrintGeneric;
use MMTests::PrintHtml;
use parent MMTests::Extract;
use constant MONITOR_CPUTIME_SINGLE	=> 1;
use constant MONITOR_VMSTAT		=> 2;
use constant MONITOR_PROCVMSTAT		=> 3;
use constant MONITOR_NUMA_CONVERGENCE	=> 4;
use constant MONITOR_NUMA_USAGE		=> 5;
use constant MONITOR_TOP		=> 6;
use constant MONITOR_LATENCY		=> 7;
use constant MONITOR_IOSTAT		=> 8;
use constant MONITOR_FTRACE		=> 9;
use constant MONITOR_IOTOP		=> 10;
use constant MONITOR_SYSCALLS		=> 11;
use constant MONITOR_PROCNETDEV		=> 12;
use constant MONITOR_KCACHE		=> 13;
use constant MONITOR_PERFTIMESTAT	=> 14;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName 	=> "Monitor",
		_DataType	=> 0,
		_FieldHeaders	=> [],
		_FieldLength	=> 0,
		_Headers	=> [ "Base" ],
	};
	bless $self, $class;
	return $self;
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub printPlot() {
        my ($self, $subheading) = @_;

	$self->sortResults();
	$self->printSummary($subheading);
}

sub extractSummary() {
	my ($self) = @_;

	if ($self->{_MultiopMonitor}) {
		if ($self->{_SingleSample}) {
			# Drop second column for summarization as it has a
			# sample or timestamp which is meaningless in the
			# context of a single sample
			foreach my $rowRef (@{$self->{_ResultData}}) {
				push @{$self->{_SummaryData}}, [ $rowRef->[0], $rowRef->[2] ];
			}
		} else {
			# Drop the first column as it has an operation.
			# Typically this is used in the context of a
			# graph where the operation is filtered but
			# the timestamp or sample is relevant.
			foreach my $rowRef (@{$self->{_ResultData}}) {
				push @{$self->{_SummaryData}}, [ $rowRef->[1], $rowRef->[2] ];
			}
		}
		$self->{_SummaryHeaders} = [ "", "" ];
		$self->{_FieldFormat} = [ $self->{_FieldFormat}->[0], $self->{_FieldFormat}->[2] ];
	} else {
		$self->{_SummaryData} = $self->{_ResultData};
		$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	}
	return 1;
}

1;
