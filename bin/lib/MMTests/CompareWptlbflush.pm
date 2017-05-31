# CompareWptlbflush.pm
package MMTests::CompareWptlbflush;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareWptlbflush",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
