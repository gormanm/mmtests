# ExtractDvdstoreexectime.pm
package MMTests::ExtractDvdstoreexectime;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractDvdstoreexectime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Opname}     = "ExecTime";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/dvdstoreexectime/dvdstore/;

	my @files = <$reportDir/dvdstore-*>;
	foreach my $file (@files) {
		next if $file =~ /.*\.failed$/;
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		my $file = "$reportDir/time-$client";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			$self->addData($client, 0, $self->_time_to_elapsed($_));
		}
		close(INPUT);
	}
}

1;
