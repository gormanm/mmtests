# ExtractPoundtime.pm
package MMTests::ExtractPoundtime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractPoundtime";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $iteration;

	my %hashCases;
	my @testcases;
	my @files = <$reportDir/noprofile/*-*.time>;
	foreach my $file (@files) {
		$file =~ s/.*\///;
		$file =~ s/-.*//;
		$hashCases{$file} = 1;
	}
	@testcases = sort keys %hashCases;
	undef %hashCases;

	my @clients;
	my @files = <$reportDir/noprofile/$testcases[0]-*-1.time>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		foreach my $testcase (@testcases) {
			my $iteration = 0;
			my @files = <$reportDir/noprofile/$testcase-$client-*.time>;
			foreach my $file (@files) {
				open(INPUT, $file) || die("Failed to open $file\n");
				while (<INPUT>) {
					next if $_ !~ /elapsed/;
					push @{$self->{_ResultData}}, [ "real-$testcase-$client", ++$iteration, $self->_time_to_elapsed($_) ];
					push @{$self->{_ResultData}}, [ "syst-$testcase-$client", ++$iteration, $self->_time_to_sys($_) ];
				}
				close(INPUT);
			}
		}
	}

	my @operations;
	foreach my $cpu ("real", "syst") {
		foreach my $testcase (@testcases) {
			foreach my $client (@clients) {
				push @operations, "$cpu-$testcase-$client";
			}
		}
	}
	$self->{_Operations} = \@operations;
}

1;
