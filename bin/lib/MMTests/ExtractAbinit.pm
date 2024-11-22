# ExtractAbinit.pm
package MMTests::ExtractAbinit;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractAbinit";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "histogram";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @files = <$reportDir/abinit-time.*>;
	my @stages;
	foreach my $file (@files) {
		my $stage = $file;
		$stage =~ s/.*abinit-time.//;
		open(INPUT, "$reportDir/stage-$stage.name");
		my $name = <INPUT>;
		chomp $name;
		close(INPUT);
		push @stages, $name;

		$self->parse_time_all($file, $name, 1);
	}

	my @ratioops;
	foreach my $stage (@stages) {
		push @ratioops, "elsp-$stage";
	}
}
