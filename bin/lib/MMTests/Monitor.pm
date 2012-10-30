# Monitor.pm
#
# This is base class description for modules that parse MM Tests directories
# and extract from the monitors

package MMTests::Monitor;

use VMR::Report;
use MMTests::Print;
use constant MONITOR_CPUTIME_SINGLE	=> 1;
use constant MONITOR_VMSTAT		=> 2;
use constant MONITOR_PROCVMSTAT		=> 3;
use constant MONITOR_NUMA_CONVERGENCE	=> 4;
use constant MONITOR_NUMA_USAGE		=> 5;
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

sub getModuleName() {
	my ($self) = @_;
	return $self->{_ModuleName};
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my (@fieldHeaders);
	my ($fieldLength);

	if ($self->{_DataType} == MONITOR_CPUTIME_SINGLE) {
		$fieldLength = 12;
		@fieldHeaders = ("", "User", "System", "Elapsed");
	}
	$self->{_FieldLength}  = $fieldLength;
	$self->{_FieldHeaders} = \@fieldHeaders;
	$self->{_PrintHandler} = MMTests::Print->new();
	$self->{_TestName} = $testName;
}

sub printFieldHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_FieldLength}, $self->{_FieldHeaders},
		$self->{_FieldHeaderFormat});
}

sub printReport() {
	my ($self) = @_;
	if ($self->{_DataType} == MONITOR_CPUTIME_SINGLE ||
	    $self->{_DataType} == MONITOR_PROCVMSTAT ||
	    $self->{_DataType} == MONITOR_VMSTAT) {
		$self->{_PrintHandler}->printGeneric($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
	} else {
		print "Unknown data type for reporting raw data\n";
	}
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	return 1;
}

1;
