# CompareSeeker.pm
package MMTests::CompareSeeker;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSeeker",
		_DataType    => MMTests::Compare::DATA_OPS_PER_SECOND,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
