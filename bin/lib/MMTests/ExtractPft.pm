# ExtractPft.pm
package MMTests::ExtractPft;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

use MMTests::Stat;
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractPft";
	$self->{_PlotYaxis}  = DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Precision} = 4;
	$self->{_FieldLength} = 14;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $wallTime, $faultsCpu, $faultsSec);
	my $dummy;

	my @clients = $self->discover_scaling_parameters($reportDir, "pft-", ".log");;

	foreach my $client (@clients) {
		my $nr_samples = 0;
		my $file = "$reportDir/pft-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			$line =~ tr/s//d;
			if ($line =~ /[a-zA-Z]/) {
				next;
			}

			# Output of program looks like
			# MappingSize  Threads CacheLine   UserTime  SysTime WallTime flt/cpu/s fault/wsec
			($dummy, $dummy, $dummy, $dummy,
		 	$user, $system, $wallTime,
		 	$faultsCpu, $faultsSec) = split(/\s+/, $line);

			$nr_samples++;
			$self->addData("faults/cpu-$client", $nr_samples, $faultsCpu);
			$self->addData("faults/sec-$client", $nr_samples, $faultsSec);
		}
		close INPUT;
	}

	my @ops;
	foreach my $heading ("faults/cpu", "faults/sec") {
		foreach my $client (@clients) {
			push @ops, "$heading-$client";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
