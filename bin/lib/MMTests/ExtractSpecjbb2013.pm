# ExtractSpecjbb2013.pm
package MMTests::ExtractSpecjbb2013;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpecjbb2013",
		_DataType    => MMTests::Extract::DATA_ACTIONS,
		_ResultData  => [],
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

	my @files = <$reportDir/$profile/$pagesize/result/specjbb2013-*/report-*/*.raw>;
	my $file = $files[0];
	die if ($file eq "");

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /jbb2013.result.group.count = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "Group Count", $1 ];
		}
		if ($line =~ /jbb2013.result.metric.max-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "Max JOPS", $1 ];
		}
		if ($line =~ /jbb2013.result.metric.critical-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "Critical JOPS", $1 ];
		}
		if ($line =~ /jbb2013.result.SLA-10000-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "SLA 10000us", $1 ];
		}
		if ($line =~ /jbb2013.result.SLA-50000-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "SLA 50000us", $1 ];
		}
		if ($line =~ /jbb2013.result.SLA-100000-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "SLA 100000us", $1 ];
		}
		if ($line =~ /jbb2013.result.SLA-200000-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "SLA 200000us", $1 ];
		}
		if ($line =~ /jbb2013.result.SLA-500000-jOPS = ([0-9]+)/) {
			push @{$self->{_ResultData}}, [ "SLA 500000us", $1 ];
		}
	}
	close INPUT;


}

1;
