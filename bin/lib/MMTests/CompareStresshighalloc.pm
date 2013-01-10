# CompareStresshighalloc.pm
package MMTests::CompareStresshighalloc;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

use constant DATA_STRESSHIGHALLOC       => 400;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareStresshighalloc",
		_DataType    => MMTests::Extract::DATA_STRESSHIGHALLOC,
		_FieldLength => 12,
		_Precision   => 2,
		_CompareOps  => [ "none", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
