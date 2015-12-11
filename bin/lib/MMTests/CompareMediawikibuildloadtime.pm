# CompareMediawikibuildloadtime.pm
package MMTests::CompareMediawikibuildloadtime;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareMediawikibuildloadtime",
		_DataType    => MMTests::Compare::DATA_TIME_SECONDS,
		_CompareOps  => [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
