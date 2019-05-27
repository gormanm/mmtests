# ExtractFsmark.pm
package MMTests::ExtractFsmark;
use MMTests::SummariseVariableops;
our @ISA = qw(MMTests::SummariseVariableops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFsmark";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
        $self->{_ExactSubheading} = 1;
        $self->{_PlotType} = "simple-filter";
        $self->{_DefaultPlot} = "1";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $iteration = 1;
	my @instances = $self->discover_scaling_parameters($reportDir, "fsmark-", ".log.gz");

	foreach my $instance (@instances) {
		my $file = "$reportDir/fsmark-$instance.log.gz";
		my $preamble = 1;
		my $enospace = 0;
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($preamble) {
				if ($line !~ /^FSUse/) {
					next;
				}
				$preamble = 0;
				next;
			}

			next if ($line =~ /Insufficient free space/);
			next if ($line =~ /No space/);

			my @elements = split(/\s+/, $_);
			$self->addData("$instance-files/sec", ++$iteration, $elements[4]);
		}
		close INPUT;
	}
}

1;
