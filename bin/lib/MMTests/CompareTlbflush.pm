# CompareTlbflush.pm
package MMTests::CompareTlbflush;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareTlbflush",
		_DataType    => MMTests::Compare::DATA_THROUGHPUT,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pdiff", "pndiff", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
