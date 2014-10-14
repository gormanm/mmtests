# ExtractLmbench.pm
package MMTests::ExtractLmbench;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractLmbench",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $size = 0;

	my ($file, $case);
	my @candidates = ( "lat_mmap", "lat_ctx" );

	foreach $case (@candidates) {
		$file = "$reportDir/noprofile/lmbench-$case.log";
		open(INPUT, $file) && last;
	}
	die("Failed to open any of @candidates") if (tell(INPUT) == -1) ;
	my $nr_samples = 0;
	my @ops;
	while (<INPUT>) {
		my $line = $_;
		if ($line =~ /^mmtests-size:([0-9]+)/) {
			$size = $1;
			$nr_samples = 0;
			next;
		}
		if ($line =~ /^[0-9].*/) {
			my @elements = split(/\s+/, $_);
			$elements[0] =~ s/\..*/M/;
			push @{$self->{_ResultData}}, [ "$elements[0]-$size", ++$nr_samples, $elements[1] ];
			if ($nr_samples == 1) {
				push @ops, "$elements[0]-$size";
			}
			next;
		}
	}
	close INPUT;
	$self->{_Operations} = \@ops;
}

1;
