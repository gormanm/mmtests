# CompareSpecjbb2015.pm
package MMTests::CompareSpecjbb2015;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareSpecjbb2015",
	};
	bless $self, $class;
	return $self;
}

1;
