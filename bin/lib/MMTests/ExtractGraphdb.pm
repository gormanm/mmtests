# ExtractGraphdb.pm
package MMTests::ExtractGraphdb;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractGraphdb",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_PlotType    => "simple-filter",
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_Opname} = "Latency";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @ops;

	my $start_timestamp;
	my $file = "$reportDir/graphdb.log";
	if (-e "$reportDir/graphdb.log") {
		open(INPUT, "sort -n $file|");
	} elsif (-e "$reportDir/graphdb.log.gz") {
		open(INPUT, "gunzip -c $file | sort -n |");
	} else {
		die("No graphdb.log");
	}

	while (!eof(INPUT)) {
		my $line = <INPUT>;


		next if ($line !~ /[0-9]* [a-z]* [0-9]*$/);
		my ($timestamp, $op, $latency) = split(/\s+/, $line);

		if ($start_timestamp == 0) {
			$start_timestamp = $timestamp;
		}
		$self->addData($op, $timestamp - $start_timestamp, $latency );
	}

	$self->{_Operations} = [ "read", "write", "mmap", "munmap" ];
	close INPUT;
}

1;
