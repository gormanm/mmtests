# CompareNas.pm
package MMTests::CompareNas;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareNas",
		_Precision   => 2,
		_CompareOps  => [ "none", "pndiff" ],
	};
	bless $self, $class;
	return $self;
}

1;
