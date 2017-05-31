# CompareNetpipe4mb.pm
package MMTests::CompareNetpipe4mb;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareNetpipe4mb",
		_CompareOps  => [ "none", "pdiff", "pdiff", "pndiff", "pndiff", "pdiff", "pdiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
