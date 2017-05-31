# CompareDbench3.pm
package MMTests::CompareDbench3;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbench3",
		_CompareOp   => "pdiff",
	};
	bless $self, $class;
	return $self;
}

1;
