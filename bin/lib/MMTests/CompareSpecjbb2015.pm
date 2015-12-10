# CompareSpecjbb2015.pm
package MMTests::CompareSpecjbb2015;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpecjbb2015",
		_DataType    => MMTests::Compare::DATA_OPSSEC,
		_FieldLength => 15,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
