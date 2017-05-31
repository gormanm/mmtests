# CompareDbench4opslatency.pm
package MMTests::CompareDbench4opslatency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbench4opslatency",
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
