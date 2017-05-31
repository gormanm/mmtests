# CompareInterbenchdeadline.pm
package MMTests::CompareInterbenchdeadline;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareInterbenchdeadline",
		_CompareOp   => "pndiff",
		_Precision   => 4,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
