# ExtractPgioperf.pm
package MMTests::ExtractPgioperf;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPgioperf",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "Operations/sec,TestName,Latency,candlesticks";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_Opname} = "Latency";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $recent = 0;

	open(INPUT, "$reportDir/noprofile/pgioperf.log") || die("Failed to open $reportDir/noprofile/pgioperf.log");
	my %samples;
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		if ($line =~ /([a-z]+)\[[0-9]+\]: avg: ([0-9.]+) msec; max: ([0-9.]+) msec/) {

			my $op = $1;
			my $avg = $2;
			my $max = $3;
			push @{$self->{_ResultData}}, [ $op, ++$samples{$op}, $max ];
		}
	}
	my @ops = keys %samples;
	$self->{_Operations} = \@ops;
	close INPUT;
}

1;
