# ExtractInterbenchdeadline.pm
package MMTests::ExtractInterbenchdeadline;
use MMTests::SummariseVariabletime;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractInterbenchdeadline",
		_DataType    => MMTests::Extract::DATA_TIME_MSECONDS,
		_Percision   => 4,
		_PlotType    => "simple-filter",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_Opname} = "DeadlineMissed";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my @threads;
	my @ops;

	$reportDir =~ s/nterbenchdeadline/nterbench/;
	foreach my $file (<$reportDir/$profile/interbench-*.latency>) {
		my @elements = split (/-/, $file);
		my $thr = $elements[-1];
		$thr =~ s/.latency//;
		push @threads, $thr;
	}

	foreach my $thread (@threads) {
		my $start_timestamp;
		my $last_comparison;
		my $file = "$reportDir/$profile/interbench-$thread.latency";

		open(INPUT, $file) || die("$file");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			my ($timestamp, $load, $latency, $deadline_miss) = split(/\s+/, $line);

			if ($last_comparison ne $load) {
				$start_timestamp = $timestamp;
				$last_comparison = $load;
				push @ops, $load;
			}

			push @{$self->{_ResultData}}, [ $load, $timestamp - $start_timestamp, $deadline_miss / 1000 ];
		}
	}

	my %seen;
	my @ops = sort @ops;
	grep !$seen{$_}++, @ops;

	$self->{_Operations} = \@ops;
	close INPUT;
}

1;
