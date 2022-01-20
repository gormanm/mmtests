package MMTests::ExtractPerffutexwake;
use MMTests::SummariseSubselection;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSubselection);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	my $fieldLength = 12;
	$self->{_ModuleName} 		= "ExtractPerffutexwake";
	$self->{_DataType}   		= DataTypes::DATA_TIME_MSECONDS;
	$self->{_PlotType}   		= "client-errorlines";
	$self->{_Precision}		= 4;
        $self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;

	@clients = $self->discover_scaling_parameters($reportDir, "perffutexwake-", ".log.gz");

	foreach my $client (@clients) {
		my $input = $self->SUPER::open_log("$reportDir/perffutexwake-$client.log");
		my $iteration = 0;
		while (<$input>) {
			my $line = $_;
			if ($line =~ /Run.*: Wokeup.* in ([0-9.]*) ([a-z]*)/) {
				die "Units of time $2 not recognised" if ($2 ne "ms");

				$self->addData("$client", ++$iteration, $1);
			}
		}
		close($input);
	}
}

1;
