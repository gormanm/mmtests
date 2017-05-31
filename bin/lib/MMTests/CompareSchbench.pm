# CompareSchbench.pm
package MMTests::CompareSchbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSchbench",
		_CompareOp  => "pndiff",
		_Variable    => 1,
	};
	bless $self, $class;
	return $self;
}

1;
