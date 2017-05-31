# CompareDvdstoreexectime.pm
package MMTests::CompareDvdstoreexectime;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDvdstoreexectime",
		_CompareOps  => [ "pndiff", "pndiff", "pndiff", "pndiff", "pndiff", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
