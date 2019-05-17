# ExtractJohnripperexectime.pm
package MMTests::ExtractJohnripperexectime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractJohnripperexectime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_Opname}     = "ExecTime";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my @clients;
	$reportDir =~ s/johnripperexectime/johnripper/;

	my @files = <$reportDir/load-*-1.time>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	# Extract per-client timing information
	foreach my $client (@clients) {
		my $iteration = 0;

		foreach my $file (<$reportDir/load-$client-*.time>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("User-$client", ++$iteration, $self->_time_to_user($_));
				$self->addData("System-$client", ++$iteration, $self->_time_to_sys($_));
				# $self->addData("Elapsd-$client", ++$iteration, $self->_time_to_elapsed($_));
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
