# CompareDbt5exectime.pm
package MMTests::CompareDbt5exectime;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbt5exectime",
		_CompareOps  => [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
