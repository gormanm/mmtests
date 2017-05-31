# CompareGraphdb.pm
package MMTests::CompareGraphdb;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareGraphdb",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
