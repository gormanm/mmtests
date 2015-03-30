# ComparePgioperf.pm
package MMTests::ComparePgioperf;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePgioperf",
		_DataType    => MMTests::Compare::DATA_TIME_MSECONDS,
		_FieldLength => 16,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
