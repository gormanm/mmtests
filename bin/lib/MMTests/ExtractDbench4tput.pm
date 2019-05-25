package MMTests::ExtractDbench4tput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} 		= "ExtractDbench4tput";
	$self->{_DataType}   		= DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   		= "client-errorlines";
	$self->{_SubheadingPlotType}	= "simple-clients";
        $self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	$reportDir =~ s/4tput/4/;
	my @clients;

	@clients = $self->discover_scaling_parameters($reportDir, "dbench-", ".log.gz");

	foreach my $client (@clients) {
		my $file = "$reportDir/dbench-$client.log.gz";

		open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			$line =~ s/^\s+//;
			if ($line =~ /sec  execute/) {
				my @elements = split(/\s+/, $line);

				$self->addData("$client", $elements[5], $elements[2]);

				next;
			}
		}
		close INPUT;
	}
}

1;
