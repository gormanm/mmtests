# CompareTlbflush.pm
package MMTests::CompareTlbflush;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareTlbflush",
	};
	bless $self, $class;
	return $self;
}

1;
