# ExtractPoundtime.pm
package MMTests::ExtractPoundtime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractPoundtime";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "thread-errorlines";
	$self->{_ClientSubheading} = 1;
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;

	my %hashCases;
	my @testcases;
	my @files = <$reportDir/$profile/*-*.time>;
	foreach my $file (@files) {
		$file =~ s/.*\///;
		$file =~ s/-.*//;
		$hashCases{$file} = 1;
	}
	@testcases = sort keys %hashCases;
	undef %hashCases;

	my @clients;
	my @files = <$reportDir/$profile/$testcases[0]-*-1.time>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		foreach my $testcase (@testcases) {
			my $iteration = 0;
			my @files = <$reportDir/$profile/$testcase-$client-*.time>;
			foreach my $file (@files) {
				open(INPUT, $file) || die("Failed to open $file\n");
				while (<INPUT>) {
					next if $_ !~ /elapsed/;
					push @{$self->{_ResultData}}, [ "$client-real-$testcase", ++$iteration, $self->_time_to_elapsed($_) ];
					push @{$self->{_ResultData}}, [ "$client-syst-$testcase", ++$iteration, $self->_time_to_sys($_) ];
				}
				close(INPUT);
			}
		}
	}

	my @operations;
	foreach my $cpu ("real", "syst") {
		foreach my $testcase (@testcases) {
			foreach my $client (@clients) {
				push @operations, "$client-$cpu-$testcase";
			}
		}
	}
	$self->{_Operations} = \@operations;
}

1;
