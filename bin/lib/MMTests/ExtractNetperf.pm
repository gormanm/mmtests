# ExtractNetperf.pm
package MMTests::ExtractNetperf;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractNetperf",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

my $_netperf_type;

sub printDataType() {
	print "Throughput,Packet Size (bytes),Throughput (Mbits/sec),netperf\n";
}

sub printPlot() {
	my ($self, $subheading) = @_;
	$self->printSummary();
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	my @files = <$reportDir/noprofile/netperf-*.result>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.result//;
		if ($_netperf_type != "") {
			die("Unable to handle more than 1 netperf test");
		}
		$_netperf_type = $split[-1];
	}

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f%%" ];
	$self->{_FieldHeaders} = [ "Size", "Throughput", "Limit" ];
	$self->{_SummaryHeaders} = [ "Unit", "Tput" ];
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);

	my $file = "$reportDir/noprofile/netperf-$_netperf_type.result";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements = split(/\s+/, $_);
		my $confidenceLimit = 1;

		open(LOG, "$reportDir/noprofile/$_netperf_type-$elements[0].log") ||
			die("Failed to open raw log for netperf $_netperf_type-$elements[0]");
		while (<LOG>) {
			if ($_ =~ /Confidence intervals: Throughput/) {
				my @subelements = split(/\s+/, $_);
				$confidenceLimit = $subelements[5];
			}
		}
		close LOG;

		push @{$self->{_ResultData}}, [ $elements[0], $elements[1], $confidenceLimit ];
		next;
	}
	close INPUT;
}

1;
