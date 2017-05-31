# CompareHpcc.pm
package MMTests::CompareHpcc;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareHpcc",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
