# ExtractLmbench.pm
package MMTests::ExtractLmbench;
use MMTests::ExtractSummarisePlain;
use VMR::Stat;
our @ISA = qw(MMTests::ExtractSummarisePlain); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractLmbench",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}.2f" ];
	$self->{_FieldHeaders} = [ "Proc-Size", "Latency" ];
}

sub printDataType() {
	print "WalltimeVariable,Processes,Context Switch Time\n";
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
	while (<INPUT>) {
		my $line = $_;
		if ($line =~ /^mmtests-size:([0-9]+)/) {
			$size = $1;
			next;
		}
		if ($line =~ /^[0-9].*/) {
			my @elements = split(/\s+/, $_);
			$elements[0] =~ s/\..*/M/;
			push @{$self->{_ResultData}}, [ "$elements[0]-$size",  $elements[1] ];
			next;
		}
	}
	close INPUT;
}

1;
