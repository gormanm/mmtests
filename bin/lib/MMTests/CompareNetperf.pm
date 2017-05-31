# CompareNetperf.pm
package MMTests::CompareNetperf;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareNetperf",
		_CompareOps  => [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
