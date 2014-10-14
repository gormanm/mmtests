# ComparePagealloc.pm
package MMTests::ComparePagealloc;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

use constant DATA_PAGEALLOC     => 100;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePagealloc",
		_DataType    => DATA_PAGEALLOC,
		_FieldLength => 17,
		_CompareOp   => "pndiff",
		_CompareLength => 6,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
