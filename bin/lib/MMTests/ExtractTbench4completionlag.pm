package MMTests::ExtractTbench4completionlag;
use MMTests::ExtractDbench4completionlag;
our @ISA = qw(MMTests::ExtractDbench4completionlag);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->SUPER::initialise($subHeading);
	$self->{_LogPrefix} = "tbench";
}

1;
