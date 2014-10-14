# CompareFfsb.pm
package MMTests::CompareFfsb;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFfsb",
		_DataType    => MMTests::Compare::DATA_OPSSEC,
		_FieldLength => 13,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
