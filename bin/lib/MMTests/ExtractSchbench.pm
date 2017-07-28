# ExtractSchbench.pm
package MMTests::ExtractSchbench;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);

use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSchbench";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;
	$self->{_PlotXaxis}  = "Threads";
	$self->{_Opname} = "Lat";
	$self->{_FieldLength} = 12;
	$self->{_ExactSubheading} = 1;
	$self->{_ExactPlottype} = "simple";
	$self->{_DefaultPlot} = "1";
	$self->{_SingleType} = 1;
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my %singleInclude;

	my @files = <$reportDir/$profile/schbench-*.log>;
	my @groups;

	foreach my $file (@files) {
		my @split = split /-/, $file;
		my $group = $split[-1];

		$group =~ s/([0-9]+).*/$1/;

		push @groups, $group
	}
	@groups = sort { $a <=> $b } @groups;

	foreach my $group (@groups) {
		open(INPUT, "$reportDir/$profile/schbench-$group.log") || die("Failed to open $group\n");
		while (<INPUT>) {
			if ($_ =~ /[ \t\*]+([0-9]+\.[0-9]+)th: ([0-9]+)/) {
				my $quartile = $1;
				my $lat = $2;
				$quartile =~ s/00$//;
				push @{$self->{_ResultData}}, ["${quartile}th-qrtle-$group", $lat];
				if ($quartile == 99) {
					$singleInclude{"${quartile}th-qrtle-$group"} = 1;
				}
			}
		}
		close INPUT;
	}

	$self->{_SingleInclude} = \%singleInclude;
}
