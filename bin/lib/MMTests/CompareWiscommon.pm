# CompareWiscommon.pm
package MMTests::CompareWiscommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareWiscommon",
		_CompareOp   => "pdiff",
	};
	bless $self, $class;
	return $self;
}

1;
