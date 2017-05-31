# CompareDbt2bench.pm
package MMTests::CompareDbt2bench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbt2bench",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
