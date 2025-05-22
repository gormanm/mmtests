package MMTests::ExtractTbench4completionspread;
use MMTests::ExtractDbench4completionspread;
our @ISA = qw(MMTests::ExtractDbench4completionspread);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->SUPER::initialise($subHeading);
	$self->{_LogPrefix} = "tbench";
}

1;
