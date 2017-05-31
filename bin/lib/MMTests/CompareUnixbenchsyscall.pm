# CompareUnixbenchsyscall.pm
package MMTests::CompareUnixbenchsyscall;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareUnixbenchsyscall",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
