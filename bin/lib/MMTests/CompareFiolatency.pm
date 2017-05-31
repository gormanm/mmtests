# CompareFiolatency.pM
package MMTests::CompareFiolatency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFiolatency",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
