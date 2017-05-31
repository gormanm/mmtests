# ExtractPfttime.pm
package MMTests::ExtractPfttime;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

use VMR::Stat;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPfttime",
		_DataType    => DataTypes::DATA_TIME_SECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

my $_pagesize = "base";

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($user, $system, $wallTime, $faultsCpu, $faultsSec);
	my $dummy;
	$reportDir =~ s/pfttime-/pft-/;

	my @clients;
        my @files = <$reportDir/$profile/$_pagesize/pft-*.log>;
        foreach my $file (@files) {
                my @split = split /-/, $file;
                $split[-1] =~ s/.log//;
                push @clients, $split[-1];
        }
        @clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $nr_samples = 0;
		my $file = "$reportDir/$profile/$_pagesize/pft-$client.log";
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
			push @{$self->{_ResultData}}, [ "system-$client", $nr_samples, $system ];
			push @{$self->{_ResultData}}, [ "elapsed-$client", $nr_samples, $wallTime ];
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
