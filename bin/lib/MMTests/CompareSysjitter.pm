# CompareSysjitter.pm
package MMTests::CompareSysjitter;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSysjitter",
		_DataType    => MMTests::Extract::DATA_TIME_NSECONDS,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
