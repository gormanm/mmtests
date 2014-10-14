# CompareAim9.pm
package MMTests::CompareAim9;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

use constant DATA_AIM9 => 600;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareAim9",
		_DataType    => DATA_AIM9,
		_FieldLength => 12,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
