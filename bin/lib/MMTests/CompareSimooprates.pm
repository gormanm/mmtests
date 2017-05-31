# CompareSimooprates.pm
package MMTests::CompareSimooprates;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSimooprates",
	};
	bless $self, $class;
	return $self;
}

1;
