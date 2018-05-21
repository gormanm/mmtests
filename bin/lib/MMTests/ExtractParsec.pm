# ExtractParsec.pm
package MMTests::ExtractParsec;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_ModuleName} = "ExtractParsec";
	$self->{_DataType}   = DataTypes::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "process-errorlines";
	$self->{_RatioMatch} = "^elsp-.*";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	foreach my $file (<$reportDir/$profile/time.*>) {
		my $nr_samples = 0;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($line =~ /([0-9]):([0-9.]+)elapsed/) {
				push @{$self->{_ResultData}}, [ "user", ++$nr_samples, $self->_time_to_user($line) ];
				push @{$self->{_ResultData}}, [ "syst", ++$nr_samples, $self->_time_to_sys($line) ];
				push @{$self->{_ResultData}}, [ "elsp", ++$nr_samples, $self->_time_to_elapsed($line) ];
			}
		}
		close INPUT;
	}

	$self->{_Operations} = [ "user", "syst", "elsp" ];
}
