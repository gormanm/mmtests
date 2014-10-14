# ExtractSysbenchloadtime.pm
package MMTests::ExtractSysbenchloadtime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSysbenchloadtime",
		_DataType    => MMTests::Extract::DATA_TIME_SECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	$reportDir =~ s/sysbenchloadtime/sysbench/;

	my @clients;
	my @files = <$reportDir/noprofile/default/sysbench-raw-*-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract load times if available
	$iteration = 0;
	foreach my $client (@clients) {
		if (open (INPUT, "$reportDir/noprofile/default/load-$client.time")) {
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				push @{$self->{_ResultData}}, [ "loadtime", ++$iteration, $self->_time_to_elapsed($_) ];
			}
			close INPUT;
		}
	}

	$self->{_Operations} = [ "loadtime" ];
}

1;
