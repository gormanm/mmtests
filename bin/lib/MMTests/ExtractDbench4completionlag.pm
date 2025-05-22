package MMTests::ExtractDbench4completionlag;
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
	$self->{_LogPrefix}		= "dbench";
	$self->SUPER::initialise($subHeading);
	$self->{_FieldFormat} = [ "%-${fieldLength}.3f", "%${fieldLength}d" ];
}

sub compare_time() {

	my @elements_a = split(/\s+/, $a);
	my @elements_b = split(/\s+/, $b);

	return $elements_a[7] <=> $elements_b[7];
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients = $self->discover_scaling_parameters($reportDir, "$self->{_LogPrefix}-", ".log.gz");

	foreach my $client (@clients) {
		my @time_sorted;
		my @completions;
		my $last_timestamp = 0;

		my $input = $self->SUPER::open_log("$reportDir/$self->{_LogPrefix}-$client.log");
		while (<$input>) {
			my $line = $_;
			if ($line =~ /completed in/) {
				chomp($line);
				$line =~ s/^\s+//;
				push @time_sorted, $line;
			}
		}
		@time_sorted = sort compare_time @time_sorted;
		close($input);

		my @window_start;	# Start of a new window
		my @window_end;		# End of a window, all clients completed once
		my @window_seen;	# Number of clients seen
		my @worker_window;	# Window a client belongs to

		@worker_window = (0) x $client;

		#print "BEGIN $client\n";
		foreach my $line (@time_sorted) {
			#print "$line\n";
			my @elements = split(/\s+/, $line);

			my $worker = $elements[0];
			my $duration = $elements[3];
			my $timestamp = $elements[7];
			my $window = $worker_window[$worker];

			# Client has finished a window, move client to next window and
			# initialise the start time if necessary
			$worker_window[$worker]++;

			# Have all clients finished the window?
			$window_seen[$window]++;
			#print "Worker finish $worker:$window end $timestamp finished $window_seen[$window]/$client\n";
			if ($window_seen[$window] == $client) {
				my $duration = $timestamp - $window_start[$window];
				#print "WINDOW $window FINISH duration $duration ms\n";
				$self->addData("$client", $window, $duration);
			}

			if ($window_start[$worker_window[$worker]] == 0) {
				$window_start[$worker_window[$worker]] = $timestamp;
				#print "Worker $worker INIT NEW WINDOW[$worker_window[$worker]] $timestamp\n";
			}

			next;

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
				$last_timestamp = $timestamp;
				undef @completions;
			}
		}
	}
}

1;
