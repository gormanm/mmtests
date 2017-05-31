# CompareAim9.pm
package MMTests::CompareAim9;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareAim9",
		_DataType    => MMTests::Extract::DATA_OPS_PER_SECOND,
	};
	bless $self, $class;
	return $self;
}

1;
