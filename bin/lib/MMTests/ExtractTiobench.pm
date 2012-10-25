# ExtractTiobench.pm
package MMTests::ExtractTiobench;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTiobench",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/tiobench-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;
	$self->{_Clients} = \@clients;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Operation", "MB/sec" , "CPU", "AvgLatency", "MaxLatency", "%gt2sec", "%gt10sec" ];
	$self->{_SummaryHeaders} = [ "Operation", "MB/sec", "CPU", "AvgLatency", "MaxLatency", "%gt2sec", "%gt10sec" ];
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @clients = @{$self->{_Clients}};
	my $op;
	my $reading = 0;

	foreach my $client (@clients) {
		my $file = "$reportDir/noprofile/tiobench-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;

			if ($reading) {
				my @elements = split(/\s+/, $_);
				push @{$self->{_ResultData}}, [ "$op-$client", $elements[4], $elements[5], $elements[6], $elements[7], $elements[8], $elements[9] ];
				$reading = 0;
				next;
			}

			chomp($line);
			if ($line eq "Sequential Reads") {
				$reading = 1;
				$op = "SeqRead";
				next;
			}
			if ($line eq "Random Reads") {
				$reading = 1;
				$op = "RandRead";
				next;
			}
			if ($line eq "Sequential Writes") {
				$reading = 1;
				$op = "SeqWrite";
				next;
			}
			if ($line eq "Random Writes") {
				$reading = 1;
				$op = "RandWrite";
				next;
			}
		}
		close INPUT;
	}
}

1;
