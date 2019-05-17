# ExtractThpscalecounts.pm
package MMTests::ExtractThpscalecounts;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractThpscalecounts";
	$self->{_DataType}   = DataTypes::DATA_ACTIONS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Percentage";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	$reportDir =~ s/thpscalecounts/thpscale/;

	my @ops;
	my @clients;
	my @files = <$reportDir/threads-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $faults = 0;
		my $inits = 0;
		my $base = 0;
		my $huge = 0;

		my $file = "$reportDir/threads-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
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
		close INPUT;

		if ($huge + $base != 0) {
			$self->addData("huge-$client", 0, $huge * 100 / ($huge + $base) );
		} else {
			$self->addData("huge-$client", 0, -1);
		}
	}
}

1;
