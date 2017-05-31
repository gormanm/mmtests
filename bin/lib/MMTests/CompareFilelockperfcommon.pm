# CompareFilelockperfcommon.pm
package MMTests::CompareFilelockperfcommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFilelockperfcommon",
		_DataType    => MMTests::Extract::DATA_TIME_SECONDS,
		_FieldLength => 12,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
