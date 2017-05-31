# ComparePerfnuma.pm
package MMTests::ComparePerfnuma;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePerfnuma",
		_CompareOps  => [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
