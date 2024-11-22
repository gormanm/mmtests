# ExtractStutterpcalibrate.pm
package MMTests::ExtractStutterpcalibrate;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);

use strict;
my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStutterp",
		_PlotYaxis   => DataTypes::LABEL_MBYTES_PER_SECOND,
		_PreferredVal => "Higher",
		_Precision   => 4,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	# Extract calibration write test throughput
	my $file = "$reportDir/calibrate.time";
	open(INPUT, $file) || die("Failed to open $file\n");
	my @elements = split(/ /, <INPUT>);
	@elements = split(/:/, $elements[2]);
	close(INPUT);
	$self->addData("Write", 0, (1024) / ($elements[0] * 60 + $elements[1]) );
}
1;
