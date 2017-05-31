# CompareKernbench.pm
package MMTests::CompareKernbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareKernbench",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
