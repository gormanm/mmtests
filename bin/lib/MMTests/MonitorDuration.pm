# MonitorDuration.pm
package MMTests::MonitorDuration;
use MMTests::Monitor;
our @ISA = qw(MMTests::Monitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorDuration",
		_DataType    => MMTests::Monitor::MONITOR_CPUTIME_SINGLE,
		_ResultData  => [],
		_MultiopMonitor => 1,
		_SingleSample => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $testName, $testBenchmark) = @_;
	my $fieldLength = 12;
	my $file = "$reportDir/tests-timestamp-$testName";

	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = [ "Op", "", "Duration" ];
	$self->{_FieldFormat} = [ "${fieldLength}s", "", "%${fieldLength}.2f" ];

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		if ($_ =~ /^time \:\: $testBenchmark (.*)/) {
			my $dummy;
			my ($user, $system, $elapsed);

			($user, $dummy,
			 $system, $dummy,
			 $elapsed, $dummy) = split(/\s/, $1);

			$self->addData("User", 0, $user );
			$self->addData("System", 0, $system );
			$self->addData("Elapsed", 0, $elapsed );
		}
	}
	close INPUT;
}

1;
