# CompareVmscale.pm
package MMTests::CompareVmscale;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareVmscale",
		_ResultData  => [],
		_FieldLength => 25,
	};
	bless $self, $class;
	return $self;
}

1;
