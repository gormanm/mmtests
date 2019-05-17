# ExtractLtp.pm
package MMTests::ExtractLtp;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractLtp";
	$self->{_DataType}   = DataTypes::DATA_BAD_ACTIONS;
	$self->{_SingleType} = 1;
	$self->{_Opname} = "Test";

	$self->SUPER::initialise($subHeading);
}

my %status_code = (
	"exit=exited"	=> 0,
	"exit=signaled"	=> 10,
	"exit=stopped"	=> 20,
	"exit=unknown"	=> 30,
);

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @collections;
	foreach my $file (<$reportDir/ltp-*.log>) {
		my @split = split /\//, $file;
		$split[-1] =~ s/.log.*//;
		$split[-1] =~ s/^ltp-//;
		push @collections, $split[-1];
	}
	sort @collections;

	foreach my $collection (@collections) {
		my $file = "$reportDir/ltp-$collection.log";

		open(INPUT, $file) || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;

			next if $line !~ /^tag=/;
			my @split = split /\s+/, $line;
			$split[0] =~ s/^tag=//;
			$split[4] =~ s/stat=//;

			die if !defined $status_code{$split[3]};
			$self->addData("$collection-$split[0]", 0, $split[3] + $split[4]);
		}
		close(INPUT);
	}
}

1;
