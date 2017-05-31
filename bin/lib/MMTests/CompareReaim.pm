# CompareReaim.pm
package MMTests::CompareReaim;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareReaim",
	};
	bless $self, $class;
	return $self;
}

1;
