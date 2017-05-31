# CompareTimeexit.pm
package MMTests::CompareTimeexit;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareTimeexit",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
