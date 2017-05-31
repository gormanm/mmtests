# CompareXfsioops.pm
package MMTests::CompareXfsioops;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareXfsioops",
		_CompareOp   => "pdiff",
	};
	bless $self, $class;
	return $self;
}

1;
