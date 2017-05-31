# CompareTimeexit.pm
package MMTests::CompareKu_latency;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareKu_latency",
		_CompareOp   => "pndiff",
	};
	bless $self, $class;
	return $self;
}

1;
