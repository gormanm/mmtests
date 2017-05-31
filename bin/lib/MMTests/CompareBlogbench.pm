# CompareBlogbench.pm
package MMTests::CompareBlogbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareBlogbench",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
