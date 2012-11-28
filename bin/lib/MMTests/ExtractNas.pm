# ExtractNas.pm
package MMTests::ExtractNas;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

use VMR::Stat;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPft",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

my $_pagesize = "default";

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @kernels;

	my @files = <$reportDir/noprofile/$_pagesize/*.log>;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		$split[-1] =~ s/.log//;
		push @kernels, $split[-1];
	}
	$self->{_Kernels} = \@kernels;

	my $fieldLength = 12;
	$self->{_TestName} = $testName;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = ["Kernel", "Time" ];
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_FieldFormat} = [ "%-8s", "%${fieldLength}.2f" ];
	$self->{_FieldHeaderFormat} = [ "%-8s", "%${fieldLength}s" ];
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($wallTime);
	my $dummy;
	my @kernels = @{$self->{_Kernels}};

	die("No data") if $kernels[0] eq "";

	foreach my $kernel (@kernels) {
		my $file = "$reportDir/noprofile/$_pagesize/$kernel.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /\s+Time in seconds =\s+([0-9.]+)/) {
				push @{$self->{_ResultData}}, [ $kernel, $1 ];
				last;
			}
		}
		close INPUT;
	}
}

1;
