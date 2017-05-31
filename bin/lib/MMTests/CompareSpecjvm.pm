# CompareSpecjvm.pm
package MMTests::CompareSpecjvm;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpecjvm",
		_DataType    => MMTests::Extract::DATA_OPS_PER_MINUTE,
		_FieldLength => 13,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
