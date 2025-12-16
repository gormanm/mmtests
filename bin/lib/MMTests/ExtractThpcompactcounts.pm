# ExtractThpcompactcounts.pm
package MMTests::ExtractThpcompactcounts;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractThpcompactcounts";
	$self->{_PlotYaxis}  = "Percentage";
	$self->{_PlotType}   = "histogram";
	$self->{_PreferredVal} = "Higher";
	$self->{_Opname}     = "Percentage";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = $self->discover_scaling_parameters($reportDir, "threads-", ".log.gz");

	foreach my $client (@clients) {
		my $base = 0;
		my $huge = 0;

		my $input = $self->SUPER::open_log("$reportDir/threads-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /^fault/) {
				my @elements = split(/\s+/, $line);
				if ($elements[2] eq "base") {
					$base++;
				} else {
					$huge++;
				}
			}
		}
		close $input;

		if ($huge + $base != 0) {
			$self->addData("huge-$client", 0, $huge * 100 / ($huge + $base) );
		} else {
			$self->addData("huge-$client", 0, -1);
		}
	}
}

1;
