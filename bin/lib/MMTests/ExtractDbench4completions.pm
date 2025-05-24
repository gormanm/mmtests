package MMTests::ExtractDbench4completions;
use MMTests::SummariseSubselection;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSubselection);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	my $fieldLength = 12;
	$self->{_ModuleName} 		= "ExtractDbench4completions";
	$self->{_PlotYaxis}  		= DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PlotType}   		= "client-errorlines";
	$self->{_SubheadingPlotType}	= "simple-clients";
	$self->{_LogPrefix}		= "dbench-loadfile";
	$self->SUPER::initialise($subHeading);
	$self->{_FieldFormat} = [ "%-${fieldLength}.3f", "%${fieldLength}d" ];
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "$self->{_LogPrefix}-", ".log.[g|x]z");

	foreach my $client (@clients) {
		my $nr_samples = 0;
		my $last_timestamp = 0;
		my @completions;

		my $input = $self->SUPER::open_log("$reportDir/$self->{_LogPrefix}-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /completed in/) {
				$line =~ s/^\s+//;
				my @elements = split(/\s+/, $line);

				# Look for what is probably a negative wrap
				next if ($elements[3] > (1<<31));

				my $worker = $elements[0];
				my $duration = $elements[3];
				my $timestamp = int ($elements[7] / 1000);

				$completions[$timestamp]++;
				$last_timestamp = $timestamp if $timestamp > $last_timestamp;
			}
		}
		close($input);

		for (my $i = 0; $i < $last_timestamp; $i++) {
			$self->addData("$client", $i, $completions[$i] );
		}
	}
}

1;
