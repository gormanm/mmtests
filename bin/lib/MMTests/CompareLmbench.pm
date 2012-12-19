# CompareLmbench.pm
package MMTests::CompareLmbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareLmbench",
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
	my ($self, $format, $extractModulesRef) = @_;
	$self->SUPER::initialise($format, $extractModulesRef);

	my @extractModules = @{$self->{_ExtractModules}};
	$extractModules[0]->{_SummaryHeaders} = [ "Time", "Procs" ];
}

1;
