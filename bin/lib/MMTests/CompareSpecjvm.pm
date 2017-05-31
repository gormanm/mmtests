# CompareSpecjvm.pm
package MMTests::CompareSpecjvm;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpecjvm",
	};
	bless $self, $class;
	return $self;
}

1;
