# ExtractThpscalelocality.pm
package MMTests::ExtractThpscalelocality;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractThpscalelocality";
	$self->{_DataType}   = DataTypes::DATA_ACTIONS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Percentage";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients = $self->discover_scaling_parameters($reportDir, "threads-", ".log.gz");;

	foreach my $client (@clients) {
		my @local = 0;
		my @remote = 0;
		my $faults = 0;
		my $uncertain = 0;

		my $input = $self->SUPER::open_log("$reportDir/threads-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /^fault/) {
				$faults++;
				my $size;

				my @elements = split(/\s+/, $line);
				if ($elements[2] eq "base") {
					$size = 0;
				} else {
					$size = 1;
				}
				
				if ($elements[5] == 1) {
					$local[$size]++;
				} elsif ($elements[5] == 0) {
					$remote[$size]++;
				} else {
					$uncertain++;
				}
			}
		}
		close $input;

		if ($faults != 0) {
			$self->addData("local-base-$client", 0, $local[0] * 100 / $faults);
			$self->addData("local-huge-$client", 0, $local[1] * 100 / $faults);
			$self->addData("remote-base-$client", 0, $remote[0] * 100 / $faults);
			$self->addData("remote-huge-$client", 0, $remote[1] * 100 / $faults);
			if ($uncertain != 0) {
				$self->addData("uncertain-$client", 0, $uncertain * 100 / $faults);
			}
		} else {
			$self->addData("local-$client", 0, -1);
		}
	}
}

1;
