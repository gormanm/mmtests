# CompareEbizzythread.pm
package MMTests::CompareEbizzythread;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareEbizzythread",
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff", "pdiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
