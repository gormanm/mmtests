# CompareXfsrepair.pm
package MMTests::CompareXfsrepair;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareXfsrepair",
		_CompareOps  => [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
