# CompareVmrstream.pm
package MMTests::CompareVmrstream;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareVmrstream",
		_DataType    => MMTests::Extract::DATA_MBYTES_PER_SECOND,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
