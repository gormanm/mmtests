# CompareDbench4.pm
package MMTests::CompareDbench4;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbench4",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
