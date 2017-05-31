# CompareSpecjbb.pm
package MMTests::CompareSpecjbb;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpecjbb",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_FieldLength => 13,
		_ResultData  => [],
		_CompareOps  => [ "none", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
