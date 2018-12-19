# ExtractStutter.pm
package MMTests::ExtractStutter;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);

use strict;
my @_threads;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStutter",
		_DataType    => DataTypes::DATA_TIME_MSECONDS,
		_ResultData  => [],
		_Precision   => 4,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($user, $system, $elapsed, $cpu);

	# Extract parallel mmap latency
	my $file = "$reportDir/$profile/mmap-latency.log";
	my $nr_samples = 1;
	my $nr_delayed = 0;
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my ($instances, $latency) = split(/ /);
		for (my $i = 0; $i < $instances; $i++) {
			$self->addData("mmap", $nr_samples++, $latency / 1000000);
		}
		if ($latency > 5000000) {
			$nr_delayed += $instances;
		}
	}
	close(INPUT);
	$self->{_DelayedSamples} = $nr_delayed;
	$self->{_Operations} = [ "mmap" ];
}
1;
