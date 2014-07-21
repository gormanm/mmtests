# MonitorFtrace.pm
package MMTests::MonitorFtrace;
use MMTests::Monitor;
our @ISA = qw(MMTests::Monitor); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "MonitorFtrace",
		_DataType    => MMTests::Monitor::MONITOR_FTRACE,
		_RowOrientated => 1,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub ftraceCallback {
	die("Base ftrace class cannot analyse anything.\n");
}

# Static regex used. Specified like this for readability and for use with /o
#		      (process_pid)     (cpus      )   ( time  )   (tpoint    ) (details)
#my $regex_traceevent = '\s*([a-zA-Z0-9-]*)\s*(\[[0-9]*\])\s*([0-9.]*):\s*([a-zA-Z_]*):\s*(.*)';
my $regex_traceevent = '\s*([a-zA-Z0-9-]*)\s*(\[[0-9]*\])\s*[.0-9a-zA-Z]*\s*([0-9.]*):\s*([a-zA-Z_]*):\s*(.*)';
my $regex_statname = '[-0-9]*\s\((.*)\).*';
my $regex_statppid = '[-0-9]*\s\(.*\)\s[A-Za-z]\s([0-9]*).*';

sub generate_traceevent_regex {
	my ($self, $event, $default) = @_;
	my $regex;

	# Read the event format or use the default
	if (!open (FORMAT, "/sys/kernel/debug/tracing/events/$event/format")) {
		return $default;
	} else {
		my $line;
		while (!eof(FORMAT)) {
			$line = <FORMAT>;
			$line =~ s/, REC->.*//;
			if ($line =~ /^print fmt:\s"(.*)".*/) {
				$regex = $1;
				$regex =~ s/%s/\([0-9a-zA-Z|_]*\)/g;
				$regex =~ s/%p/\([0-9a-f]*\)/g;
				$regex =~ s/%d/\([-0-9]*\)/g;
				$regex =~ s/%u/\([0-9]*\)/g;
				$regex =~ s/%ld/\([-0-9]*\)/g;
				$regex =~ s/%lu/\([0-9]*\)/g;
			}
		}
	}

	# Can't handle the print_flags stuff but in the context of this
	# script, it really doesn't matter
	$regex =~ s/\(REC.*\) \? __print_flags.*//;
	my @expected_list = split(/\s/, $default);

	# Verify fields are in the right order
	my $tuple;
	foreach $tuple (split /\s/, $regex) {
		my ($key, $value) = split(/=/, $tuple);
		my $expected = shift @expected_list;
		$expected =~ s/=.*//;
		if ($key ne $expected) {
			print("WARNING: Format not as expected for event $event '$key' != '$expected'\n");
			$regex =~ s/$key=\((.*)\)/$key=$1/;
		}
	}

	if (defined shift @expected_list) {
		die("Fewer fields than expected in format for $event");
	}

	return $regex;
}

# Convert sec.usec timestamp format
sub timestamp_to_ms($) {
	my $timestamp = $_[0];

	my ($sec, $usec) = split (/\./, $timestamp);
	return ($sec * 1000) + ($usec / 1000);
}

sub extractReport($$$) {
	my ($self, $reportDir, $testName, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my %last_procmap;

	my $file = "$reportDir/ftrace-$testName-$testBenchmark";
	if (-e $file) {
		open(INPUT, $file) || die("Failed to open $file: $!\n");
	} else {
		$file .= ".gz";
		open(INPUT, "gunzip -c $file|") || die("Failed to open $file: $!\n");
	}

	$self->ftraceInit();

	while (!eof(INPUT)) {
		my $traceevent = <INPUT>;
		if ($traceevent !~ /$regex_traceevent/o) {
			print("WARNING: $traceevent");
			next;
		}

		my $process_pid = $1;
		my $timestamp = timestamp_to_ms($3);;
		my $tracepoint = $4;
		my $details = $5;

		$process_pid =~ /(.*)-([0-9]*)$/;
		my $process = $1;
		my $pid = $2;

		if ($process eq "") {
			$process = $last_procmap{$pid};
			$process_pid = "$process-$pid";
		}
		$last_procmap{$pid} = $process;
		$self->ftraceCallback($timestamp, $pid, $process, $tracepoint, $details);
	}
	close INPUT;

	$self->ftraceReport($rowOrientated);
}

1;
