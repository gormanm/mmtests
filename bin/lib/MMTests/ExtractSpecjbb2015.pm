# ExtractSpecjbb2015.pm
package MMTests::ExtractSpecjbb2015;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpecjbb2015",
		_DataType    => DataTypes::DATA_ACTIONS,
		_PlotType    => "histogram",
		_SingleType  => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $jvm_instance = -1;
	my $reading_tput = 0;
	my @jvm_instances;
	my $specjbb_bops;
	my $specjbb_bopsjvm;
	my $single_instance;
	my $pagesize = "base";

	if (! -e "$reportDir/$profile/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/$profile/$pagesize") {
		$pagesize = "default";
	}

	my @files = <$reportDir/$profile/$pagesize/result/specjbb2015-*/report-*/*.raw>;
	my $file = $files[0];
	if ($file eq "") {
		system("tar -C $reportDir/$profile/$pagesize -xf $reportDir/$profile/$pagesize/result.tar.gz");
		@files = <$reportDir/$profile/$pagesize/result/specjbb2015-*/report-*/*.raw>;
		$file = $files[0];
		die if ($file eq "");
	}

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /jbb2015.result.metric.max-jOPS = ([0-9]+)/) {
			$self->addData("Max-JOPS", 0, $1);
		}
		if ($line =~ /jbb2015.result.metric.critical-jOPS = ([0-9]+)/) {
			$self->addData("Critical-JOPS", 0, $1);
		}
		if ($line =~ /jbb2015.result.SLA-([0-9]+)-jOPS = ([0-9]+)/) {
			$self->addData("SLA-$1us", 0, $2);
		}
	}
	close INPUT;


}

1;
