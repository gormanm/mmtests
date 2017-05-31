# CompareDbt5bench.pm
package MMTests::CompareDbt5bench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbt5bench",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
