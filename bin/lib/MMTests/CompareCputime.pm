# CompareCputime.pm
package MMTests::CompareCputime;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareCputime",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
