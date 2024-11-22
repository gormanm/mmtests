package MMTests::ExtractDbench4tput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} 		= "ExtractDbench4tput";
	$self->{_PlotYaxis}  		= DataTypes::LABEL_MBYTES_PER_SECOND;
	$self->{_PreferredVal}		= "Higher";
	$self->{_PlotType}   		= "client-errorlines";
	$self->{_SubheadingPlotType}	= "simple-clients";
	$self->{_LogPrefix}		= "dbench";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = $self->discover_scaling_parameters($reportDir, "$self->{_LogPrefix}-", ".log.gz");

	foreach my $client (@clients) {

		my $input = $self->SUPER::open_log("$reportDir/$self->{_LogPrefix}-$client.log");
		while (<$input>) {
			my $line = $_;
			$line =~ s/^\s+//;
			if ($line =~ /sec  execute/) {
				my @elements = split(/\s+/, $line);

				$self->addData("$client", $elements[5], $elements[2]);
			}
		}
		close($input);
	}
}

1;
