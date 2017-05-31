# CompareSysbench.pm
package MMTests::CompareSysbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSysbench",
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
