# CompareParallelio.pm
package MMTests::CompareParallelio;
use VMR::Stat;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareParallelio",
	};
	bless $self, $class;
	return $self;
}

1;
