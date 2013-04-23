#!/usr/bin/perl
# This takes the text output from blkparse and reports requests that took
# too long to complete, what requests were in flight at the time that
# request was queued and what requests were completed while it was in
# flight.
#
# This is an UGLY script that is slow due to the use of a text format and
# far more memory intensive than it needed to me. The aim was to implement
# something fast, not implement something that executed fast.
#
# Copyright Mel Gorman 2013

use strict;

my $nr_requests;
my %inflight;
my %completed;

sub sprint_request(%)
{
	my %request = %{$_[0]};

	return sprintf "%5d %4s %12d %12s\n", $request{PID}, $request{TYPE}, $request{START}, $request{NAME};
}

sub print_request(%)
{
	print sprint_request(@_);
}

sub find_request($$)
{
	my ($start, $end) = @_;

	foreach my $requestid (keys %inflight) {
		my %request = %{$inflight{$requestid}};
		if ($request{START} >= $start && $request{END} <= $end) {
			return $inflight{$requestid};
		}
	}

	return undef;
}

sub list_inflight
{
	my $buffer;

	foreach my $requestid (keys %inflight) {
		$buffer .= "  " . sprint_request($inflight{$requestid});
	}

	return $buffer;
}

sub add_inflight_completed
{
	my $buffer = sprint_request(@_);

	foreach my $requestid (keys %inflight) {
		${$inflight{$requestid}}{INFLIGHT_COMPLETED} .= $buffer;
	}
}

while (!eof(STDIN)) {
	# From default output
	# device CPU seq seconds.nanoseconds PID TRACE_ACTION ACTION 3-field-RWBS
	my @elements = split(/\s+/, <STDIN>);

	if ($elements[6] eq "Q") {
		$nr_requests++;

		my %request;
		$request{ID} = $nr_requests;
		$request{PID} = $elements[5];
		$request{START} = $elements[8];
		$request{END} = $elements[8] + $elements[10];
		$request{NAME} = $elements[11];
		$request{TYPE} = $elements[7];
		$request{TIME_QUEUED} = $elements[4];
		$request{INFLIGHT_QUEUED} = list_inflight();
		$request{INFLIGHT_COMPLETED} = "";
		$inflight{$nr_requests} = \%request;
	}

	if ($elements[6] eq "C") {
		my $nr_found = 0;
		my $requestRef = find_request($elements[8], $elements[8] + $elements[10]);
		while (defined $requestRef) {
			my %request = %{$requestRef};
			$nr_found++;

			add_inflight_completed($requestRef);

			$request{TIME_COMPLETED} = $elements[4];

			my $time_complete = $request{TIME_COMPLETED} - $request{TIME_QUEUED};
			if ($time_complete > 1) {
				print "Request $request{ID} took $time_complete to complete\n";
				print_request($requestRef);
				print "Request started time index $request{TIME_QUEUED}\n";
				print "Inflight while queued\n";
				print_request($requestRef);
				print($request{INFLIGHT_QUEUED});
				print "Complete since queueing\n";
				print($request{INFLIGHT_COMPLETED});
				print "----------\n";
			}
			
			# $completed{$request{ID}} = $requestRef;
			delete $inflight{$request{ID}};
			$requestRef = find_request($elements[8], $elements[8] + $elements[10]);
		}

		if ($nr_found == 0) {
			print("Request not found at $elements[4] for $elements[8]\n");
		}
	}
}
