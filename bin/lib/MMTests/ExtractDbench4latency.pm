# ExtractDbench4latency
package MMTests::ExtractDbench4latency;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "Dbench4latency.pm",
		_DataType    => DataTypes::DATA_TIME_MSECONDS,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName) = @_;
	my @clients;
	$reportDir =~ s/4latency/4/;

	my @files = <$reportDir/dbench-*.log*>;
	if ($files[0] eq "") {
		@files = <$reportDir/tbench-*.log*>;
	}
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log.*//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $nr_samples = 0;

		my $file = "$reportDir/dbench-$client.log";
		if (! -e $file) {
			$file = "$reportDir/dbench-$client.log.gz";
		}
		if (! -e $file) {
			$file = "$reportDir/tbench-$client.log";
		}
		if (! -e $file) {
			$file = "$reportDir/tbench-$client.log.gz";
		}
		if ($file =~ /.*\.gz$/) {
			open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		} else {
			open(INPUT, $file) || die("Failed to open $file\n");
		}
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /execute/) {
				my @elements = split(/\s+/, $_);

				$nr_samples++;
				$self->addData("latency-$client", $nr_samples, $elements[9]);

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
