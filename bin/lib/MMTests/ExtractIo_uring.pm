# ExtractIo_uring
package MMTests::ExtractIo_uring;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractIo_uring";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my %mult = (K=>1, M=>1000);
	my $input = $self->SUPER::open_log("$reportDir/t-io_uring.log");

	while (<$input>) {
		if ($_=~ "^IOPS=([0-9.]+)([MK])") {
			$self->addData("kIOPS", 1, $1*$mult{$2});
		}
	}
	close($input);
}

1;
