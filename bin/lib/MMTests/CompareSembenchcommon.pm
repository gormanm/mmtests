# CompareSembenchcommon.pm
package MMTests::CompareSembenchcommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSembenchcommon",
		_CompareOp   => "pdiff",
	};
	bless $self, $class;
	return $self;
}

1;
