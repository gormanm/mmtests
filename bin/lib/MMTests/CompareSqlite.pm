# CompareSqlite.pm
package MMTests::CompareSqlite;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSqlite",
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
