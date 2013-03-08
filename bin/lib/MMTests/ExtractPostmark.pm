# ExtractPostmark.pm
package MMTests::ExtractPostmark;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPostmark",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 12;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders}[0] = "Operation";
	$self->{_PlotHeaders}[0] = "Operation";
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub printSummary() {
	my ($self) = @_;

	$self->printReport();
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $recent = 0;

	my $file = "$reportDir/noprofile/postmark.log";
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
