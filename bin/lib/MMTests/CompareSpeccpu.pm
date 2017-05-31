# CompareSpeccpu.pm
package MMTests::CompareSpeccpu;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpeccpu",
		_CompareOp => 'pndiff',
	};
	bless $self, $class;
	return $self;
}

1;
