# ExtractStutterthroughput.pm
package MMTests::ExtractStutterthroughput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractStutterthroughput";
	$self->{_DataType}   = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_Precision}  = 4;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);
	$reportDir =~ s/stutterthroughput/stutter/;

	# Extract calibration write test throughput
	my $file = "$reportDir/calibrate.time";
	open(INPUT, $file) || die("Failed to open $file\n");
	my @elements = split(/ /, <INPUT>);
	@elements = split(/:/, $elements[2]);
	close(INPUT);
	$self->addData("PotentialWriteSpeed", 1, (1024) / ($elements[0] * 60 + $elements[1]) );

	# Extract filesize of write
	my $file = "$reportDir/dd.filesize";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $filesize = <INPUT>;
	close(INPUT);

	# Extract calibration write test throughput
	my @files = <$reportDir/time.*>;
	my $nr_samples = 0;
	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file\n");
		my $line = <INPUT>;
		my @elements = split(/ /, $line);
		@elements = split(/:/, $elements[2]);
		$self->addData("tput", ++$nr_samples, $filesize / 1048576 / ($elements[0] * 60 + $elements[1] + 1) );
		close(INPUT);
	}
}
1;
