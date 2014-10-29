# CompareIpcscale.pm
package MMTests::CompareIpcscale;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareIpcscale",
		_FieldLength => 16,
	};
	bless $self, $class;
	return $self;
}

1;
