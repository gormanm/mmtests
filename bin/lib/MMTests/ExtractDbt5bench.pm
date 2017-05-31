# ExtractDbt5bench.pm
package MMTests::ExtractDbt5bench;
use MMTests::SummariseVariabletime;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractDbt5bench",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple-filter",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_Opname} = "Latency";
	$self->SUPER::initialise($reportDir, $testName);
}

my %txmap = (
	0  => "SecurityDetail",
	1  => "BrokerVolume",
	2  => "CustomerPosition",
	3  => "MarketWatch",
	4  => "TradeStatus",
	5  => "TradeLookup",
	6  => "TradeOrder",
	7  => "TradeUpdate",
	8  => "MarketFeed",
	9  => "TradeResult",
	10 => "DataMaintainence",
);

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my @clients;

	my @files = <$reportDir/$profile/dbt5-*.mix.gz>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.mix.gz//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $start_timestamp = 0;
		my $reading = 0;

		my $file = "$reportDir/$profile/dbt5-$client.mix.gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;

			if ($line =~ /START/) {
				$reading = 1;
				next;
			}
			next if !$reading;

			my ($timestamp, $tx, $status, $latency, $token) = split(/,/, $line);
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
			next if ($status == 1);

			push @{$self->{_ResultData}}, [ "$txmap{$tx}-$client",
							$timestamp - $start_timestamp,
							$latency * 1000 ];
		}
		close(INPUT);
	}

	my @ops;
	foreach my $tx (sort values %txmap) {
		foreach my $client (@clients) {
			push @ops, "$tx-$client";
		}
	}

	$self->{_Operations} = \@ops;
}

1;
