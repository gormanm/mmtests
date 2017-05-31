# CompareParallelioswap.pm
package MMTests::CompareParallelioswap;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareParallelioswap",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
