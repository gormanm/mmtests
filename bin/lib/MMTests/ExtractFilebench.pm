# ExtractFilebench.pm
package MMTests::ExtractFilebench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFilebench";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "operation-candlesticks";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	open(INPUT, "$reportDir/model") || die("Failed to detect model");
	my $case = <INPUT>;
	chomp($case);
	close(INPUT);

	my @clients = $self->discover_scaling_parameters($reportDir, "$case-", ".1*");

	foreach my $client (@clients) {
		my $iteration = 0;
		foreach my $file (<$reportDir/$case-$client.*>) {
			my $input = $self->SUPER::open_log($file);
			my ($startSetup, $endSetup, $endRun);
			while (!eof($input)) {
				my $line = <$input>;
				if ($line =~ /[0-9]+: ([0-9.]+): Creating fileset/) {
					$startSetup = $1;
					next;
				}
				if ($line =~ /[0-9]+: ([0-9.]+): Running/) {
					$endSetup = $1;
					next;
				}

				if ($line =~ /[0-9]+: ([0-9.]+): IO Summary:\s+([0-9]+) ops, ([0-9.]+) ops.*/) {
					$self->addData("$case-$client", ++$iteration, $3);
				}
			}
			close($input);
		}
	}
}

1;
