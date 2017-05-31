# CompareSockperfunderload.pm
package MMTests::CompareSockperfunderload;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSockperfunderload",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
