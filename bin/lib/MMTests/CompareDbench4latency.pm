# CompareDbench4latency.pM
package MMTests::CompareDbench4latency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbench4latency",
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
