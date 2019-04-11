# ExtractPistress.pm
package MMTests::ExtractPistress;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractPistress";
	$self->{_DataType}   = DataTypes::DATA_BAD_ACTIONS;
	$self->{_SingleType} = 1;
	$self->{_Opname} = "Test";

	$self->SUPER::initialise($reportDir, $testName);
}

my %status_code = (
	"exit=exited"	=> 0,
	"exit=signaled"	=> 10,
	"exit=stopped"	=> 20,
	"exit=unknown"	=> 30,
);

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @clients;
	foreach my $file (<$reportDir/$profile/pistress-*.log>) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log.*//;
		push @clients, $split[-1];
	}
	sort { $a <=> $b} @clients;

	foreach my $client (@clients) {
		my $file = "$reportDir/$profile/pistress-$client.status";

		open(INPUT, $file) || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			chomp($line);
			$self->addData($client, 0, $line);
		}
		close(INPUT);
	}
}

1;
