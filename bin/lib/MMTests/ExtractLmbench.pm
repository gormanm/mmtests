# ExtractLmbench.pm
package MMTests::ExtractLmbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractLmbench",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_FieldLength => 16,
		_Precision   => 4,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $size = 0;

	my ($file, $case, $caseName);
	my @candidates = ( "lat_mmap", "lat_ctx" );

	foreach $case (@candidates) {
		$file = "$reportDir/lmbench-$case.log";
		if (open(INPUT, $file)) {
			$caseName = $case;
			last;
		}
	}
	die("Failed to open any of @candidates") if (tell(INPUT) == -1) ;
	my $nr_samples = 0;
	my %sampleSizes;
	while (<INPUT>) {
		my $line = $_;
		if ($caseName eq "lat_mmap") {
			my @elements = split(/\s+/, $_);
			my $size = (int $elements[0]) . "M";
			$self->addData("$size", ++$sampleSizes{$elements[0]}, $elements[1]);
		} else {
			if ($line =~ /^mmtests-size:([0-9]+)/) {
				$size = $1;
				$nr_samples = 0;
				next;
			}
			if ($line =~ /^[0-9].*/) {
				my @elements = split(/\s+/, $_);
				$elements[0] =~ s/\..*/M/;
				$self->addData("$elements[0]-$size", ++$nr_samples, $elements[1]);
				next;
			}
		}
	}
	close INPUT;
}

1;
