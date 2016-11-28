# ExtractJohnripperexectime.pm
package MMTests::ExtractJohnripperexectime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractJohnripperexectime";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Opname}     = "ExecTime";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/johnripperexectime/johnripper/;

	my @files = <$reportDir/$profile/load-*-1.time>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		foreach my $file (<$reportDir/$profile/load-$client-*.time>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				push @{$self->{_ResultData}}, [ "User-$client", ++$iteration, $self->_time_to_user($_) ];
				push @{$self->{_ResultData}}, [ "System-$client", ++$iteration, $self->_time_to_sys($_) ];
				# push @{$self->{_ResultData}}, [ "Elapsd-$client", ++$iteration, $self->_time_to_elapsed($_) ];
			}
			close(INPUT);
		}
	}

	foreach my $heading ("User", "System") {
		foreach my $client (@clients) {
			push @{$self->{_Operations}}, "$heading-$client";
		}
	}
}

1;
