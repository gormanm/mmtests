# CompareStresshighalloc.pm
package MMTests::CompareStresshighalloc;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

use constant DATA_STRESSHIGHALLOC       => 400;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareStresshighalloc",
		_Precision   => 2,
		_CompareOps  => [ "none", "pndiff" ],
	};
	bless $self, $class;
	return $self;
}

sub prepareForRSummary($) {
	my ($self) = @_;
	# override _CompareOps, first column is not treated specially in R
	$self->{_CompareOp} = "pndiff";
	undef($self->{_CompareOps});
}

1;
