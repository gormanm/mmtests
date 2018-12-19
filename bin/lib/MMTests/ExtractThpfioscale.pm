# ExtractThpfioscale.pm
package MMTests::ExtractThpfioscale;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractThpfioscale";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @ops;
	my @clients;
	my @files = <$reportDir/$profile/threads-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;


	foreach my $client (@clients) {
		my $faults = 0;
		my $inits = 0;
		my %seen;

		my $file = "$reportDir/$profile/threads-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /^fault/) {
				my @elements = split(/\s+/, $line);
				$self->addData("fault-$elements[2]-$client", ++$faults, $elements[3]);
				$self->addData("fault-both-$client", ++$faults, $elements[3]);
				$seen{$elements[2]} = 1;
			}
		}
		close INPUT;

		if ($seen{"base"} != 1) {
			$self->addData("fault-base-$client", 1, 0);
		}
		if ($seen{"huge"} != 1) {
			$self->addData("fault-huge-$client", 1, 0);
		}
	}

	foreach my $client (@clients) {
		push @ops, "fault-base-$client";
	}
	foreach my $client (@clients) {
		push @ops, "fault-huge-$client";
	}
	foreach my $client (@clients) {
		push @ops, "fault-both-$client";
	}

	$self->{_Operations} = \@ops;
}

1;
