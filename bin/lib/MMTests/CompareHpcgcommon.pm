# CompareHpcgcommon.pm
package MMTests::CompareHpcgcommon;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareHpcg",
		_FieldLength => 18,
		_Precision   => 5,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
