# CompareStockfish.pm
package MMTests::CompareStockfish;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareStockfish",
	};
	bless $self, $class;
	return $self;
}

1;
