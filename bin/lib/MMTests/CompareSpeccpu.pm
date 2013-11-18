# CompareSpeccpu.pm
package MMTests::CompareSpeccpu;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpeccpu",
		_DataType    => MMTests::Compare::DATA_OPSSEC,
		_FieldLength => 13,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
