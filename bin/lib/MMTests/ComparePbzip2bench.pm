# ComparePbzip2bench.pm
package MMTests::ComparePbzip2bench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePbzip2bench",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
