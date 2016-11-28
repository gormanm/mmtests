# ExtractPostmark.pm
package MMTests::ExtractPostmark;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractPostmark";
	$self->{_DataType}   = MMTests::Extract::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_SingleType} = 1;
	$self->{_SingleInclude}  = {
		"Transactions" => 1,
		"DataRead/MB"  => 1,
		"DataWrite/MB" => 1,
	};

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $recent = 0;

	my $file = "$reportDir/$profile/postmark.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /seconds of transactions \(([0-9\.]+)/) {
			push @{$self->{_ResultData}}, [ "Transactions", $1 ];
		} elsif ($line =~ /megabytes read \(([0-9\.]+)/) {
			push @{$self->{_ResultData}}, [ "DataRead/MB", $1 ];
		} elsif ($line =~ /megabytes written \(([0-9\.]+)/) {
			push @{$self->{_ResultData}}, [ "DataWrite/MB", $1 ];
		} elsif ($line =~ /Creation alone:.*\(([0-9\.]+)/) {
			push @{$self->{_ResultData}}, [ "FilesCreate", $1 ];
			$recent = 1;
		} elsif ($line =~ /Deletion alone:.*\(([0-9\.]+)/) {
			push @{$self->{_ResultData}}, [ "FilesDeleted", $1 ];
			$recent = 2;
		} elsif ($line =~ /Mixed with transactions.*\(([0-9\.]+)/) {
			if ($recent == 1) {
				push @{$self->{_ResultData}}, [ "CreateTransact", $1 ];
			} elsif ($recent == 2) {
				push @{$self->{_ResultData}}, [ "DeleteTransact", $1 ];
			}
		}
	}
	close INPUT;
}

1;
