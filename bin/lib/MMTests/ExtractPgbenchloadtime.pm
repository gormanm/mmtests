# ExtractPgbenchloadtime.pm
package MMTests::ExtractPgbenchloadtime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractPgbenchloadtime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "single-candlesticks";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/pgbenchloadtime/pgbench/;

	my @files = <$reportDir/$profile/default/pgbench-raw-*>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract load times if available
	$iteration = 0;
	foreach my $client (@clients) {
		if (open (INPUT, "$reportDir/$profile/default/load-$client.time")) {
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
