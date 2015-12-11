# ExtractMediawikibuildloadtime.pm
package MMTests::ExtractMediawikibuildloadtime;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractMediawikibuildloadtime";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_PlotType}   = "single-candlesticks";
	$self->{_FieldLength} = 12;
	$self->{_Opname}     = "Import";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tm, $tput, $latency);
	$reportDir =~ s/mediawikibuildloadtime/mediawikibuild/;

	my @import_list = ("mwdump", "image", "imagelinks", "logging", "pagelinks");

	foreach my $import (@import_list) {
		open(INPUT, "$reportDir/noprofile/time-import-$import");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			push @{$self->{_ResultData}}, [ "$import", $self->_time_to_elapsed($_) ];
		}
		close(INPUT);
	}

	my @ops;
	foreach my $import (@import_list) {
		push @ops, $import;
	}
	$self->{_Operations} = \@ops;
}

1;
