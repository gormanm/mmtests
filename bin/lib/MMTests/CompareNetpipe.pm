# CompareNetpipe.pm
package MMTests::CompareNetpipe;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareNetpipe",
		_CompareOps  => [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
