# CompareNas.pm
package MMTests::CompareNas;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareNas",
		_FieldLength => 12,
		_Precision   => 2,
		_CompareOps  => [ "none", "pndiff" ],
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
