# CompareFilebench.pm
package MMTests::CompareFilebench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFilebench",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
