# CompareFfsb.pm
package MMTests::CompareFfsb;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFfsb",
	};
	bless $self, $class;
	return $self;
}

1;
