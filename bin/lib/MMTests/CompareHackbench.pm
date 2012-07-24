# CompareHackbench.pm
package MMTests::CompareHackbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareHackbench",
		_DataType    => MMTests::Compare::DATA_WALLTIME,
		_CompareOp   => "pndiff",
		_Precision   => 4,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $extractModulesRef) = @_;
	$self->SUPER::initialise($extractModulesRef);

	my @extractModules = @{$self->{_ExtractModules}};
	$extractModules[0]->{_SummaryHeaders} = [ "Time", "Procs" ];
}

1;
