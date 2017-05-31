# CompareEbizzyrange.pm
package MMTests::CompareEbizzyrange;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareEbizzyrange",
		_DataType    => MMTests::Extract::DATA_ACTIONS_PER_SECOND,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pdiff", "pndiff", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
