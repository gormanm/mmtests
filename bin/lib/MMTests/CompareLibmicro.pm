# CompareLibmicro.pm
package MMTests::CompareLibmicro;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareLibmicro",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_CompareOp   => "pndiff",
		_Precision   => 4,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
