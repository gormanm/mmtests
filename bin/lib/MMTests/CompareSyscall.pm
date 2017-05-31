# CompareSyscall.pm
package MMTests::CompareSyscall;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSyscall",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
