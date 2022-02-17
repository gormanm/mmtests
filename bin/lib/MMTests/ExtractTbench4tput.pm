package MMTests::ExtractTbench4tput;
use MMTests::ExtractDbench4tput;
our @ISA = qw(MMTests::ExtractDbench4tput);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->SUPER::initialise($subHeading);
	$self->{_LogPrefix} = "tbench";
}

1;
