# CompareParallelio.pm
package MMTests::CompareParallelio;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareParallelio",
		_DataType    => MMTests::Compare::DATA_OPSSEC,
		_FieldLength => 18,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
