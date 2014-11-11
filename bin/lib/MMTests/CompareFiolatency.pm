# CompareFiolatency.pM
package MMTests::CompareFiolatency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFiolatency",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
