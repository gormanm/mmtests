# ExtractFsmarkoverhead.pm
package MMTests::ExtractFsmarkoverhead;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFsmarkoverhead";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_USECONDS;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);
	$reportDir =~ s/overhead//;
	my $iteration = 1;

	$reportDir =~ s/fsmark-singleoverhead/fsmark-single/;
	$reportDir =~ s/fsmark-threadedoverhead/fsmark-threaded/;

	my @instances = $self->discover_scaling_parameters($reportDir, "fsmark-", ".log.gz");

	foreach my $instance (@instances) {
		my $preamble = 1;
		my $input = $self->SUPER::open_log("$reportDir/fsmark-$instance.log");
		while (<$input>) {
			my $line = $_;
			if ($preamble) {
				if ($line !~ /^FSUse/) {
					next;
				}
				$preamble = 0;
				next;
			}

			my @elements = split(/\s+/, $_);
			$self->addData("overhead-$instance", ++$iteration, $elements[5]);
		}
		close($input);
	}
}

1;
