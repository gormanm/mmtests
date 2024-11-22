# ExtractPfttime.pm
package MMTests::ExtractPfttime;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

use MMTests::Stat;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPfttime",
		_PlotYaxis   => DataTypes::LABEL_TIME_SECONDS,
	};
	bless $self, $class;
	return $self;
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
			$self->addData("system-$client", $nr_samples, $system);
			$self->addData("elapsed-$client", $nr_samples, $wallTime);
		}
		close INPUT;
	}

	my @ops;
	foreach my $heading ("system", "elapsed") {
		foreach my $client (@clients) {
			push @ops, "$heading-$client";
		}
	}
	$self->{_Operations} = \@ops;
}

1;
