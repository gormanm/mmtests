package MMTests::ExtractDbench4completionspread;
use MMTests::SummariseSubselection;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSubselection);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	my $fieldLength = 12;
	$self->{_ModuleName} 		= "ExtractDbench4completionspread";
	$self->{_PlotYaxis}  		= DataTypes::LABEL_OPS_SPREAD;
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
		my @time_sorted;
		my @completions;
		my $last_timestamp = 0;

		my $input = $self->SUPER::open_log("$reportDir/$self->{_LogPrefix}-$client.log");
		while (!eof($input)) {
			my $line = <$input>;
			chomp($line);
			next if $line !~ /completed in/;
			my @elements = split(/\s+/, $line);

			my $worker = $elements[0];
			my $duration = $elements[3];
			my $timestamp = int ($elements[7] / 1000);

			# Look for what is probably a negative wrap
			next if ($duration > (1<<31));

			$completions[$worker]++;
			if ($timestamp > $last_timestamp) {
				my $max = $completions[0];
				my $min = $completions[0];
				for (my $i = 0; $i < $client; $i++) {
					$max = $completions[$i] if $completions[$i] > $max;
					$min = $completions[$i] if $completions[$i] < $min;
				}
				my $spread = $max - $min;
				$self->addData("$client", $last_timestamp, $spread );
				$last_timestamp = $timestamp;
				undef @completions;
			}
		}
		close($input);
	}
}

1;
