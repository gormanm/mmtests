# ComparePgioperfbench.pm
package MMTests::ComparePgioperfbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePgioperfbench",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_FieldLength => 16,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
