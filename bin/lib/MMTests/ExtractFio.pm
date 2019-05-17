# ExtractFio
package MMTests::ExtractFio;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractFio";
	$self->{_DataType}   = DataTypes::DATA_KBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

        $self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $file = "$reportDir/fio.log";

	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file\n");
	} else {
		open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz\n");
	}
	while (<INPUT>) {
		my @elements;
		my $worker;

		@elements = split(/;/, $_);
		$worker = $elements[2];
		# Total read KB > 0?
		if ($elements[5] > 0) {
			$self->addData("kb/sec-$worker-read", 1, $elements[44]);
		}
		# Total written KB > 0?
		if ($elements[46] > 0) {
			$self->addData("kb/sec-$worker-write", 1, $elements[85]);
		}
	}
	close INPUT;
}

1;
