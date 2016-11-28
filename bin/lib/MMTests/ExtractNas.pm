# ExtractNas.pm
package MMTests::ExtractNas;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use VMR::Stat;
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractNas";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($wallTime);
	my $dummy;

	my $_pagesize = "default";
	if (! -e "$reportDir/$profile/$_pagesize") {
		$_pagesize = "base";
	}
	if (! -e "$reportDir/$profile/$_pagesize") {
		$_pagesize = "transhuge";
	}

	my @files = <$reportDir/$profile/$_pagesize/*.log>;
	my @kernels;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		$split[-1] =~ s/.log//;
		push @kernels, $split[-1];
	}

	die("No data") if $kernels[0] eq "";

	foreach my $kernel (@kernels) {
		my $file = "$reportDir/$profile/$_pagesize/$kernel.log";
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
