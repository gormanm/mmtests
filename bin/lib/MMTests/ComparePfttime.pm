# ComparePfttime.pm
package MMTests::ComparePfttime;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ComparePfttime",
		_CompareOps  => [ "none", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_Precision   => 4,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
