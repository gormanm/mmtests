# CompareThpscalecounts.pm
package MMTests::CompareThpscalecounts;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareThpscalecounts",
		_DataType    => DATA_ACTIONS,
		_FieldLength => 12,
		_CompareOp   => "pdiff",
		_CompareLength => 6,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
