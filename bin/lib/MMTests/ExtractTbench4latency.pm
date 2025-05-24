package MMTests::ExtractTbench4latency;
use MMTests::ExtractDbench4latency;
our @ISA = qw(MMTests::ExtractDbench4latency);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->SUPER::initialise($subHeading);
	$self->{_LogPrefix} = "tbench-execute";
}

1;
