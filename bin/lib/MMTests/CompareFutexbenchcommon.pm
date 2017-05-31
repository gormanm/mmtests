# CompareFutexbenchcommon.pm
package MMTests::CompareFutexbenchcommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFutexbenchcommon",
		_CompareOp   => "pdiff",
	};
	bless $self, $class;
	return $self;
}

1;
