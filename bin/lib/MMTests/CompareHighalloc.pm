# CompareHighalloc.pm
package MMTests::CompareHighalloc;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

use constant DATA_HIGHALLOC => 500;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareHighalloc",
		_DataType    => DATA_HIGHALLOC,
		_FieldLength => 12,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
