# ExtractDbt2bench.pm
package MMTests::ExtractDbt2bench;
use MMTests::SummariseVariabletime;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractDbt2bench",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
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
	"d" => "Delivery",
	"n" => "NewOrder",
	"o" => "OrderStatus",
	"p" => "Payment",
	"s" => "StockLevel"
);

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/dbt2-*.mix>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.mix//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client transaction information
	foreach my $client (@clients) {
		my $start_timestamp = 0;
		my $reading = 0;

		my $file = "$reportDir/noprofile/dbt2-$client.mix";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (!eof(INPUT)) {
			my $line = <INPUT>;

			if ($line =~ /START/) {
				$reading = 1;
				next;
			}

			$reading = 0 if $line =~ /TERMINATED/;
			next if !$reading;

			my ($timestamp, $tx, $status, $latency, $token) = split(/,/, $line);
			if ($start_timestamp == 0) {
				$start_timestamp = $timestamp;
			}
			if ($txmap{$tx} eq "") {
				print "DEBUG: $tx\n";
			}

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
