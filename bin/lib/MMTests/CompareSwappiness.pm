# CompareSwappiness.pm
package MMTests::CompareSwappiness;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSwappiness",
		_DataType    => MMTests::Compare::DATA_ACTIONS,
	};
	bless $self, $class;
	return $self;
}

1;
