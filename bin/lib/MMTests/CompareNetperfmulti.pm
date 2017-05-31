# CompareNetperfmulti.pm
package MMTests::CompareNetperfmulti;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareNetperfmulti",
		_CompareOps  => [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
