# ExtractXfsrepair.pm
package MMTests::ExtractXfsrepair;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;


sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractXfsrepair";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_MultiInclude} = {
		"elapsd-xfsrepair" => 1,
	};

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
				push @{$self->{_ResultData}}, [ "system-$testcase", ++$iteration, $self->_time_to_sys($_) ];
				push @{$self->{_ResultData}}, [ "elapsd-$testcase", ++$iteration, $self->_time_to_elapsed($_) ];
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
