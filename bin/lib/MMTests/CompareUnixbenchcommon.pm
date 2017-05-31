# CompareUnixbenchcommon.pm
package MMTests::CompareUnixbenchcommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareUnixbenchcommon",
		_CompareOp   => "pdiff",
	};
	bless $self, $class;
	return $self;
}

1;
