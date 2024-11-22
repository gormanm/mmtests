# ExtractSaladfork.pm
package MMTests::ExtractSaladfork;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSaladfork";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_USECONDS;

	$self->SUPER::initialise($subHeading);
}

sub parseNumactl {
	my ($numactl) = @_;
	my %cpu_node;

	open(INPUT, "gunzip -c $numactl|") || die("Failed to open numactl output $numactl");
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		next if $line !~ /^node ([0-9]*) cpus: (.*)/;

		my $node = $1;
		for my $cpu (split(/\s/, $2)) {
			$cpu_node{$cpu} = $node;
		}
	}
	close INPUT;

	return %cpu_node;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my %cpu_node = parseNumactl("$reportDir/../../numactl.txt.gz");

	my $nr_samples_local = 0;
	my $nr_samples_remote = 0;
	my $file = "$reportDir/saladfork-0.log.gz";
	open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
	while (<INPUT>) {
		if ($_ !~ /([0-9]+)\s+([0-9]+)\s+([.0-9]+)/) {
			next;
		}

		# cpuids in $line are zero-padded like 000, 001, 002 etc
		# cpuids in %cpu_node are not. We convert string -> int -> string to remove padding.
		my $parent_cpu = "" . int($1);
		my $child_cpu = "" . int($2);

		my $latency = $3;
		if ($cpu_node{$parent_cpu} == $cpu_node{$child_cpu}) {
			$self->addData("local", ++$nr_samples_local, $latency);
		} else {
			$self->addData("remote", ++$nr_samples_remote, $latency);
		}
	}
	close INPUT;

	# If we don't have any local (or remote) fork, add a placeholder NaN
	if ($nr_samples_local == 0) {
		$self->addData("local", 1, NaN);
	}
	if ($nr_samples_remote == 0) {
		$self->addData("remote", 1, NaN);
	}

	# An additional "syntethic" operation: ratio of local forks VS total
	my $local_v_total = $nr_samples_local / ($nr_samples_local + $nr_samples_remote);
	$self->addData("local_v_total", 1, $local_v_total);
}
1;
