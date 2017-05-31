# CompareTbench4.pm
package MMTests::CompareTbench4;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareTbench4",
		_CompareOps  => [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
