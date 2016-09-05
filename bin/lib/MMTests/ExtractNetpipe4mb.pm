# ExtractNetpipe4mb
package MMTests::ExtractNetpipe4mb;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractNetpipe4mb";
	$self->{_DataType}   = MMTests::Extract::DATA_MBITS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

        $self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $nr_samples = 0;
	$reportDir =~ s/netpipe4mb/netpipe/;

	my $file = "$reportDir/noprofile/netpipe.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		$line =~ s/^\s+//;
		my @elements = split(/\s+/, $line);

		if ($elements[0] > 1000000 && $elements[0] <= 2000000) {
			push @{$self->{_ResultData}}, [ "tput-1-2mb", ++$nr_samples, $elements[1] ];
		}
		if ($elements[0] > 2000000 && $elements[0] <= 3000000) {
			push @{$self->{_ResultData}}, [ "tput-2-3mb", ++$nr_samples, $elements[1] ];
		}
		if ($elements[0] > 3000000 && $elements[0] <= 4000000) {
			push @{$self->{_ResultData}}, [ "tput-3-4mb", ++$nr_samples, $elements[1] ];
		}
		if ($elements[0] > 4000000) {
			push @{$self->{_ResultData}}, [ "tput-g-4mb", ++$nr_samples, $elements[1] ];
		}
	}
	close INPUT;

	$self->{_Operations} = [ "tput-1-2mb", "tput-2-3mb", "tput-3-4mb", "tput-g-4mb" ];
}

1;
