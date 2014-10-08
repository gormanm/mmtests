# ExtractNetperf.pm
package MMTests::ExtractNetperf;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractNetperf",
		_DataType    => MMTests::Extract::DATA_MBITS_PER_SECOND,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_Opname} = "Tput";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);

	open (INPUT, "$reportDir/noprofile/protocols");
	my $protocol = <INPUT>;
	chomp($protocol);
	close(INPUT);

	my @sizes;
	my @files = <$reportDir/noprofile/$protocol-*.log>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		my $size = $elements[-1];
		$size =~ s/.log//;
		push @sizes, $size;
	}
	@sizes = sort {$a <=> $b} @sizes;

	foreach my $size (@sizes) {
		my $file = "$reportDir/noprofile/$protocol-$size.log";
		my $confidenceLimit;
		my $throughput;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my @elements = split(/\s+/, $_);
			if ($_ =~ /Confidence intervals: Throughput/) {
				my @subelements = split(/\s+/, $_);
				$confidenceLimit = $subelements[5];
				next;
			}
			if ($_ =~ /[a-zA-Z]/ || $_ =~ /^$/) {
				next;
			}
			my @elements = split(/\s+/, $_);
			if ($#elements > 3) {
				$throughput = $elements[-1];
			}
		}
		close(INPUT);
		push @{$self->{_ResultData}}, [ $size, $throughput ];
	}
	close INPUT;
}

1;
