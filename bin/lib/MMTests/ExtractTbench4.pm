package MMTests::ExtractTbench4;
use MMTests::ExtractDbench4;
our @ISA = qw(MMTests::ExtractDbench4);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->SUPER::initialise($subHeading);
	$self->{_LogPrefix} = "tbench-loadfile";
}

1;
