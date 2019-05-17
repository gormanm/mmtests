# ExtractHpcgcommon.pm
package MMTests::ExtractHpcgcommon;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractHpcg",
		_DataType    => DataTypes::DATA_OPS_PER_SECOND,
		_PlotType    => "histogram",
		_Precision   => 4,
	};
	bless $self, $class;
	return $self;
}

my %metric_map = (
	"No unique"     => "hpcg-gflops",
	"Raw DDOT"	=> "gflops-ddot",
	"Raw WAXPBY"	=> "gflops-waxpby",
	"Raw SpMV"	=> "gflops-spmv",
	"Raw MG"	=> "gflops-mg",
	"Raw Read B/W"  => "bwidth-GBsec-read",
	"Raw Write B/W" => "bwidth-GBsec-write",
	"Raw Total B/W" => "bwidth-GBsec-total",
);

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/hpcg-*.yaml>) {
		$iteration++;

		my $reading;
		open (INPUT, $file) || die("Failed to open $file");
		while (!eof(INPUT)) {
			my $line = <INPUT>;

			if ($line =~ /^GB\/s Summary/) {
				$reading = "mem-bwidth-metric";
				next;
			}

			if ($line =~ /^GFLOP\/s Summary/) {
				$reading = "hpcg-gflops";
				next;
			}

			if ($line =~ /^User Optimization Overheads/) {
				$reading = "";
				next;
			}

			next if $reading eq "";

			if ($line =~ /Total with convergence overhead: ([0-9.]*)/ && $reading eq "hpcg-gflops") {
				$self->addData("hpcg-gflops", $iteration, $1);
			}

			foreach my $pattern (keys %metric_map) {
				my $metric = $metric_map{$pattern};

				if ($line =~ /^  $pattern: ([0-9.]*)/) {
					$self->addData($metric, $iteration, $1);
				}
			}

			foreach my $metric (keys %metric_map) {
				if ($line =~ /^$metric=(.*)/) {
					$self->addData("$metric", $iteration, $1);
				}
			}
		}
		close (INPUT);
	}

	my @ops;
	foreach my $metric (sort values %metric_map) {
		push @ops, $metric;
	}

	$self->{_Operations} = \@ops;
}

1;
