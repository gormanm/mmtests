# CompareSwappiness.pm
package MMTests::CompareSwappiness;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSwappiness",
	};
	bless $self, $class;
	return $self;
}

1;
