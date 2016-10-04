# CompareLkpthroughput.pm
package MMTests::CompareLkpthroughput;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareLkpthroughput",
		_DataType    => MMTests::Compare::DATA_MBYTES_PER_SECOND,
		_FieldLength => 14,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
