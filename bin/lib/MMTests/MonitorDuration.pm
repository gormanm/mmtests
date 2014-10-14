# MonitorDuration.pm
package MMTests::MonitorDuration;
use MMTests::Monitor;
use VMR::Report;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorDuration",
		_DataType    => MMTests::Monitor::MONITOR_CPUTIME_SINGLE,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $testName, $testBenchmark) = @_;

	my $file = "$reportDir/tests-timestamp-$testName";

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		if ($_ =~ /^time \:\: $testBenchmark (.*)/) {
			my $dummy;
			my ($user, $system, $elapsed);

			($user, $dummy,
			 $system, $dummy,
			 $elapsed, $dummy) = split(/\s/, $1);

			push @{$self->{_ResultData}}, [ "", $user, $system, $elapsed];
		}
	}
	close INPUT;
}

1;
