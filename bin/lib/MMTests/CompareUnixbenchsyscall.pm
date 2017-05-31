# CompareUnixbenchsyscall.pm
package MMTests::CompareUnixbenchsyscall;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareUnixbenchsyscall",
		_DataType    => MMTests::Extract::DATA_TIME_NSECONDS,
		_FieldLength => 12,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
