# CompareReaim.pm
package MMTests::CompareReaim;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareReaim",
		_DataType    => MMTests::Compare::DATA_OPSSEC,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
