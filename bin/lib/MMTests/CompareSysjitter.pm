# CompareSysjitter.pm
package MMTests::CompareSysjitter;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSysjitter",
		_CompareOps  => [ "none", "pndiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
