# ExtractSqlite.pm
package MMTests::ExtractSqlite;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSqlite";
	$self->{_DataType} = DataTypes::DATA_TRANS_PER_SECOND,
	$self->{_PlotType} = "simple";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $exclude_warmup = 0;
	my $file = "$reportDir/$profile/sqlite.log";

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my @elements = split(/\s+/);
		next if $elements[0] eq "warmup";

		$exclude_warmup = 1;
		last;
	}
	seek(INPUT, 0, 0);

	my $nr_sample = 0;
	while (<INPUT>) {
		my @elements = split(/\s+/);
		next if $exclude_warmup && $elements[0] eq "warmup";
		push @{$self->{_ResultData}}, ["Trans", $nr_sample++, $elements[1]];
	}
	close INPUT;

	$self->{_Operations} = [ "Trans" ];
}
1;
