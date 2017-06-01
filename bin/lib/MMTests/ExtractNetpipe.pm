# ExtractNetpipe
package MMTests::ExtractNetpipe;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractNetpipe";
	$self->{_DataType}   = DataTypes::DATA_MBITS_PER_SECOND;
	$self->{_PlotType}   = "simple";
	$self->{_PlotXaxis}  = "Message Size KBytes";
	$self->{_FieldLength} = 12;

        $self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $nr_samples = 0;

	my $file = "$reportDir/$profile/netpipe.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		$line =~ s/^\s+//;
		my @elements = split(/\s+/, $line);

		push @{$self->{_ResultData}}, [ "tput", $elements[0] / 1024, $elements[1] ];
	}
	close INPUT;

	$self->{_Operations} = [ "tput" ];
}

1;
