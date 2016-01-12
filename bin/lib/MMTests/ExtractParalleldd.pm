# ExtractParalleldd.pm
package MMTests::ExtractParalleldd;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractParalleldd";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Opname}     = "ExecTime";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;

	my @files = <$reportDir/noprofile/time-*-1-1>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-3];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		foreach my $file (<$reportDir/noprofile/time-$client-*>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				# push @{$self->{_ResultData}}, [ "System-$client", ++$iteration, $self->_time_to_sys($_) ];
				push @{$self->{_ResultData}}, [ "Elapsd-$client", ++$iteration, $self->_time_to_elapsed($_) ];
			}
			close(INPUT);
		}
	}

	foreach my $heading ("Elapsd") {
		foreach my $client (@clients) {
			push @{$self->{_Operations}}, "$heading-$client";
		}
	}
}

1;
