package MMTests::ExtractTbench4opslatency;
use MMTests::ExtractDbench4opslatency;
our @ISA = qw(MMTests::ExtractDbench4opslatency);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->SUPER::initialise($subHeading);
	$self->{_LogPrefix} = "tbench-execute";
}

1;
