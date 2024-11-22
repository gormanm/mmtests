# ExtractFio
package MMTests::ExtractFio;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFio";
	$self->{_PlotYaxis}  = DataTypes::LABEL_KBYTES_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";
	$self->{_FieldLength} = 12;

        $self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $input = $self->SUPER::open_log("$reportDir/fio.log");
	while (<$input>) {
		my @elements;
		my $worker;

		@elements = split(/;/, $_);
		$worker = $elements[2];
		# Total read KB > 0?
		if ($elements[5] > 0) {
			$self->addData("kb/sec-$worker-read", 1, $elements[44]);
		}
		# Total written KB > 0?
		if ($elements[46] > 0) {
			$self->addData("kb/sec-$worker-write", 1, $elements[85]);
		}
	}
	close($input);
}

1;
