package MMTests::ExtractDbench4;
use MMTests::SummariseSubselection;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSubselection);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	my $fieldLength = 12;
	$self->{_ModuleName} 		= "ExtractDbench4";
	$self->{_DataType}   		= DataTypes::DATA_TIME_MSECONDS;
	$self->{_PlotType}   		= "client-errorlines";
	$self->{_SubheadingPlotType}	= "simple-clients";
        $self->SUPER::initialise($subHeading);
	$self->{_FieldFormat} = [ "%-${fieldLength}.3f", "%${fieldLength}d" ];
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;

	@clients = $self->SUPER::discover_scaling_parameters($reportDir, "dbench-", ".log.gz");

	foreach my $client (@clients) {
		my $file = "$reportDir/dbench-$client.log.gz";

		open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /completed in/) {
				$line =~ s/^\s+//;
				my @elements = split(/\s+/, $line);

				# Look for what is probably a negative wrap
				next if ($elements[3] > (1<<31));

				$self->addData("$client", $elements[7] / 1000, $elements[3] );
			}
		}
		close INPUT;
	}
}

1;
