# CompareDbench4.pm
package MMTests::CompareDbench4;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareDbench4",
	};
	bless $self, $class;
	return $self;
}

1;
