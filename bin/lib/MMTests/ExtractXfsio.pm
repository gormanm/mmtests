# ExtractXfsio.pm
package MMTests::ExtractXfsio;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractXfsio";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Opname}     = "ExecTime";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	my $iteration;

	foreach my $file (<$reportDir/noprofile/pwrite-single.*>) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			push @{$self->{_ResultData}}, [ "System", ++$iteration, $self->_time_to_sys($_) ];
			push @{$self->{_ResultData}}, [ "Elapsd", ++$iteration, $self->_time_to_elapsed($_) ];
		}
		close(INPUT);
	}

	$self->{_Operations} = [ "System", "Elapsd" ];
}

1;
