# ExtractDbench4latency
package MMTests::ExtractDbench4latency;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "Dbench4latency.pm",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my @clients;
	$reportDir =~ s/4latency/4/;

	my @files = <$reportDir/$profile/dbench-*.log>;
	if ($files[0] eq "") {
		@files = <$reportDir/$profile/tbench-*.log>;
	}
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $nr_samples = 0;
		my $file = "$reportDir/$profile/dbench-$client.log";
		if (! -e $file) {
			$file = "$reportDir/$profile/tbench-$client.log";
		}
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);

				$nr_samples++;
				push @{$self->{_ResultData}}, [ "latency-$client", $nr_samples, $elements[9] ];

				next;
			}
		}
		close INPUT;
	}

	my @ops;
	foreach my $client (@clients) {
		push @ops, "latency-$client";
	}

	$self->{_Operations} = \@ops;
}

1;
