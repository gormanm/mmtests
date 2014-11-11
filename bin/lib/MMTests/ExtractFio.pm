# ExtractFio
package MMTests::ExtractFio;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractFio";
	$self->{_DataType}   = MMTests::Extract::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

        $self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $file = "$reportDir/noprofile/fio.log";
	my @ops;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements;
		my $worker;

		@elements = split(/;/, $_);
		$worker = $elements[2];
		# Total read KB > 0?
		if ($elements[5] > 0) {
			push @{$self->{_ResultData}}, [ "kb/sec-$worker-read", 1, $elements[44] ];
			push @ops, "kb/sec-$worker-read";
		}
		# Total written KB > 0?
		if ($elements[46] > 0) {
			push @{$self->{_ResultData}}, [ "kb/sec-$worker-write", 1, $elements[85] ];
			push @ops, "kb/sec-$worker-write";
		}
	}
	close INPUT;

	$self->{_Operations} = \@ops;
}

1;
