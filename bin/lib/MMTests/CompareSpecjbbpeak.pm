# CompareSpecjbbpeak.pm
package MMTests::CompareSpecjbbpeak;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpecjbbpeak",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
