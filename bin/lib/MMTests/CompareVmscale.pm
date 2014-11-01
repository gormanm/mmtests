# CompareVmscale.pm
package MMTests::CompareVmscale;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareVmscale",
		_DataType    => MMTests::Compare::DATA_WALLTIME,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
