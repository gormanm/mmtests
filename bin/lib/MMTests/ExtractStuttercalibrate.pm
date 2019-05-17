# ExtractStuttercalibrate.pm
package MMTests::ExtractStuttercalibrate;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);

use strict;
my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStutter",
		_DataType    => DataTypes::DATA_MBYTES_PER_SECOND,
		_Precision   => 4,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);
	$reportDir =~ s/stuttercalibrate/stutter/;

	# Extract calibration write test throughput
	my $file = "$reportDir/calibrate.time";
	open(INPUT, $file) || die("Failed to open $file\n");
	my @elements = split(/ /, <INPUT>);
	@elements = split(/:/, $elements[2]);
	close(INPUT);
	$self->addData("Write", 0, (1024) / ($elements[0] * 60 + $elements[1]) );
}
1;
