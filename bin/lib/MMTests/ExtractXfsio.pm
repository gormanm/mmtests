# ExtractXfsio.pm
package MMTests::ExtractXfsio;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractXfsio";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my $testcase;
	my %testcases;

	foreach my $file (<$reportDir/$profile/*-time.*>) {
		$testcase = $file;
		$testcase =~ s/.*\///;
		$testcase =~ s/-time.*//;

		$testcases{$testcase} = 1;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			$self->addData("$testcase-System", ++$iteration, $self->_time_to_sys($_));
			$self->addData("$testcase-Elapsd", ++$iteration, $self->_time_to_elapsed($_));
		}
		close(INPUT);
	}

	my @operations;
	foreach $testcase (sort { $a <=> $b } keys %testcases) {
		push @operations, "$testcase-System";
		push @operations, "$testcase-Elapsd";
	}
	$self->{_Operations} = \@operations;
}

1;
