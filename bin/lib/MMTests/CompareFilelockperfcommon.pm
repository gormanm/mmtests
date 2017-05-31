# CompareFilelockperfcommon.pm
package MMTests::CompareFilelockperfcommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFilelockperfcommon",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
