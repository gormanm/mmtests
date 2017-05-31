# CompareBonnie.pm
package MMTests::CompareBonnie;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareBonnie",
	};
	bless $self, $class;
	return $self;
}

1;
