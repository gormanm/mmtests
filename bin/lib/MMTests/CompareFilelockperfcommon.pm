# CompareFilelockperfcommon.pm
package MMTests::CompareFilelockperfcommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFilelockperfcommon",
		_DataType    => MMTests::Compare::DATA_TIME_MSECONDS,
		_FieldLength => 12,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
