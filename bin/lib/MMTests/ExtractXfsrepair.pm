# ExtractXfsrepair.pm
package MMTests::ExtractXfsrepair;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractXfsrepair";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_RatioOperations} = [ "elapsd-xfsrepair" ];

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($tm, $tput, $latency);
	my $iteration;

	# my @testcases = ("sparsecreate", "fscreate", "fsmark", "xfsrepair");
	my @testcases = ("fsmark", "xfsrepair");

	foreach my $testcase (@testcases) {
		my $iteration = 0;
		my @files = <$reportDir/$profile/time.$testcase.*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				next if $_ !~ /elapsed/;
				$self->addData("system-$testcase", ++$iteration, $self->_time_to_sys($_));
				$self->addData("elapsd-$testcase", ++$iteration, $self->_time_to_elapsed($_));
			}
			close(INPUT);
		}
	}

	my @operations;
	foreach my $testcase (@testcases) {
		foreach my $cpu ("elapsd", "system") {
			push @operations, "$cpu-$testcase";
		}
	}
	$self->{_Operations} = \@operations;
}

1;
