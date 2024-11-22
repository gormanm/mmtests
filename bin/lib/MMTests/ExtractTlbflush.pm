# ExtractTlbflush.pm
package MMTests::ExtractTlbflush;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractTlbflush";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_NSECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "tlbflush-", ".log");
	foreach my $client (@clients) {
		my $iteration = 0;

		my $file = "$reportDir/tlbflush-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			if ($_ =~ /.*, cost ([0-9]*)ns.*/) {
				$self->addData("nsec-$client", ++$iteration, $1);
			}
		}
		close INPUT;
	}
}

1;
