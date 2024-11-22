# ExtractRedis.pm
package MMTests::ExtractRedis;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractRedis";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TRANS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "client-errorlines";
	$self->{_ClientSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "redis-", "-1.log");
	foreach my $client (@clients) {
		my $iteration = 1;
		foreach my $file (<$reportDir/redis-$client-*.log>) {
			open(INPUT, $file) || die("Failed to open $file: $!\n");
			while (<INPUT>) {
				my $line = $_;
				chomp($line);

				my @elements = split(/,/, $line);
				$elements[0] =~ s/ \(([0-9]+) keys\)/-$1/;
				$elements[0] =~ s/ \(.*\)//;
				$elements[0] =~ s/"//g;
				$elements[1] =~ s/"//g;

				$self->addData("$client-$elements[0]", $iteration, $elements[1]);
			}
			$iteration++;
			close(INPUT);
		}
	}
}

1;
