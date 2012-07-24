# ExtractLargecopytar.pm
package MMTests::ExtractLargecopytar;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractLargecopytar",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();
	
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldHeaders}[0] = "Operation";
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}d" ];
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
	my ($user, $system, $elapsed, $cpu);
	my $recent = 0;
	my $file;

	$file = "$reportDir/noprofile/largedd.result";
	if (! -e $file) {
		$file = "$reportDir/noprofile/largecopy.result";
	}
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		my @elements = split(/:/, $_);

		if ($elements[1] eq "Time to download tar") {
			push @{$self->{_ResultData}}, [ "DownloadTar", $elements[3] ];
		} elsif ($elements[1] eq "Time to unpack tar") {
			push @{$self->{_ResultData}}, [ "UnpackTar", $elements[3] ];
		} elsif ($elements[1] eq "Time to dd source files") {
			push @{$self->{_ResultData}}, [ "DD", $elements[3] ];
		} elsif ($elements[1] eq "Time to copy source files") {
			push @{$self->{_ResultData}}, [ "CopySource", $elements[3] ];
		} elsif ($elements[1] eq "Time to create tarfile") {
			push @{$self->{_ResultData}}, [ "CreateTar", $elements[3] ];
		} elsif ($elements[1] eq "Time to delete source") {
			push @{$self->{_ResultData}}, [ "Delete", $elements[3] ];
		} elsif ($elements[1] eq "Time to expand tar") {
			push @{$self->{_ResultData}}, [ "ExpandTar", $elements[3] ];
		}
	}
	close INPUT;
}

1;
