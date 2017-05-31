# CompareDvdstore.pm
package MMTests::CompareDvdstore;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDvdstore",
		_CompareOps  => [ "pndiff", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ],
		_Variable    => 1,
	};
	bless $self, $class;
	return $self;
}

1;
