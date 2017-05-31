# CompareSchbench.pm
package MMTests::CompareSchbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSchbench",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_CompareOp  => "pndiff",
		_Variable    => 1,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
