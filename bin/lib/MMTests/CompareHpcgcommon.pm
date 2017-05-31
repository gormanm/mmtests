# CompareHpcgcommon.pm
package MMTests::CompareHpcgcommon;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareHpcg",
		_Precision   => 5,
	};
	bless $self, $class;
	return $self;
}

1;
