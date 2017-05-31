# CompareParallelioio.pm
package MMTests::CompareParallelioio;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareParallelioio",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
