# ExtractStuttercalibrate.pm
package MMTests::ExtractStuttercalibrate;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);

use strict;
my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStutter",
		_DataType    => MMTests::Extract::DATA_MBYTES_PER_SECOND,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($user, $system, $elapsed, $cpu);
	$reportDir =~ s/stuttercalibrate/stutter/;

	# Extract calibration write test throughput
	my $file = "$reportDir/$profile/calibrate.time";
	open(INPUT, $file) || die("Failed to open $file\n");
	my @elements = split(/ /, <INPUT>);
	@elements = split(/:/, $elements[2]);
	close(INPUT);
	push @{$self->{_ResultData}}, [ "Write", (1024) / ($elements[0] * 60 + $elements[1]) ];
}
1;
