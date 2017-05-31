# CompareParallelio.pm
package MMTests::CompareParallelio;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareParallelio",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_FieldLength => 18,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
