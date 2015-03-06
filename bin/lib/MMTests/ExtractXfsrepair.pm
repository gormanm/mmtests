# ExtractXfsrepair.pm
package MMTests::ExtractXfsrepair;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractXfsrepair";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $iteration;

	# my @testcases = ("sparsecreate", "fscreate", "fsmark", "xfsrepair");
	my @testcases = ("fsmark", "xfsrepair");

	foreach my $testcase (@testcases) {
		my $iteration = 0;
		my @files = <$reportDir/noprofile/time.$testcase.*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				push @{$self->{_ResultData}}, [ "syst-$testcase", ++$iteration, $self->_time_to_sys($_) ];
				push @{$self->{_ResultData}}, [ "real-$testcase", ++$iteration, $self->_time_to_elapsed($_) ];
			}
			close(INPUT);
		}
	}

	my @operations;
	foreach my $testcase (@testcases) {
		foreach my $cpu ("real", "syst") {
			push @operations, "$cpu-$testcase";
		}
	}
	$self->{_Operations} = \@operations;
}

1;
