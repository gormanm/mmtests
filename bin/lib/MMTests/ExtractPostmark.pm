# ExtractPostmark.pm
package MMTests::ExtractPostmark;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractPostmark";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_RatioOperations} = [ "Transactions", "DataRead/MB",
		"DataWrite/MB" ];

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $recent = 0;

	my $file = "$reportDir/postmark.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /seconds of transactions \(([0-9\.]+)/) {
			$self->addData("Transactions", 0, $1);
		} elsif ($line =~ /megabytes read \(([0-9\.]+)/) {
			$self->addData("DataRead/MB", 0, $1);
		} elsif ($line =~ /megabytes written \(([0-9\.]+)/) {
			$self->addData("DataWrite/MB", 0, $1);
		} elsif ($line =~ /Creation alone:.*\(([0-9\.]+)/) {
			$self->addData("FilesCreate", 0, $1);
			$recent = 1;
		} elsif ($line =~ /Deletion alone:.*\(([0-9\.]+)/) {
			$self->addData("FilesDeleted", 0, $1);
			$recent = 2;
		} elsif ($line =~ /Mixed with transactions.*\(([0-9\.]+)/) {
			if ($recent == 1) {
				$self->addData("CreateTransact", 0, $1);
			} elsif ($recent == 2) {
				$self->addData("DeleteTransact", 0, $1);
			}
		}
	}
	close INPUT;
}

1;
