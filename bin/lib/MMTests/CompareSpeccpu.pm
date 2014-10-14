# CompareSpeccpu.pm
package MMTests::CompareSpeccpu;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpeccpu",
		_DataType    => MMTests::Compare::DATA_WALLTIME,
		_FieldLength => 13,
		_ResultData  => [],
		_CompareOp => 'pndiff',
	};
	bless $self, $class;
	return $self;
}

1;
