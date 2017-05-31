# CompareLinkbench.pm
package MMTests::CompareLinkbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareLinkbench",
		_CompareOp   => "pdiff",
	};
	bless $self, $class;
	return $self;
}

1;
