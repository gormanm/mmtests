# ExtractXfsioops.pm
package MMTests::ExtractXfsioops;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractXfsioops";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my $testcase;
	my %testcases;
	$reportDir =~ s/xfsioops/xfsio/;

	foreach my $file (<$reportDir/$profile/*-log.*>) {
		$testcase = $file;
		$testcase =~ s/.*\///;
		$testcase =~ s/-log.*//;

		$testcases{$testcase} = 1;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /.*and ([0-9.]+) ops\/sec.*/;
			$self->addData("$testcase-ops", ++$iteration, $1);
		}
		close(INPUT);
	}

	my @operations;
	foreach $testcase (sort { $a <=> $b } keys %testcases) {
		push @operations, "$testcase-ops";
	}
	$self->{_Operations} = \@operations;
}

1;
