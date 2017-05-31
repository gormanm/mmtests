# CompareAutonumabench.pm
package MMTests::CompareAutonumabench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

use constant DATA_AUTONUMABENCH     => 700;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareAutonumabench",
		_DataType    => DATA_AUTONUMABENCH,
		_CompareOp   => "pndiff",
		_CompareLength => 6,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
