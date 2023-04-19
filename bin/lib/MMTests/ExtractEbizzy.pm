# ExtractEbizzy.pm
package MMTests::ExtractEbizzy;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractEbizzy";
	$self->{_DataType}   = DataTypes::DATA_ACTIONS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	foreach my $instance ($self->discover_scaling_parameters($reportDir, "ebizzy-", "-1.log")) {
		my $iteration = 0;

		my @files = <$reportDir/ebizzy-$instance-*>;
		foreach my $file (@files) {
			my $records;

			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;
				if ($line =~ /([0-9]*) records.*/) {
					$records = $1;
				}
			}
			close $input;

			$self->addData("Rsec-$instance", $iteration, $records);
		}
	}
}

1;
