# CompareIpcscale.pm
package MMTests::CompareIpcscalecommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareIpcscalecommon",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_FieldLength => 16,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
