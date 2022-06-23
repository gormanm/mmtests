#!/bin/bash
install-depends iotop
if [ -e /proc/sys/kernel/task_delayacct ]; then
	echo 1 > /proc/sys/kernel/task_delayacct
fi
exec iotop -k -b -d $MONITOR_UPDATE_FREQUENCY 2>&1 | perl -e 'while (<>) {
	my $line = $_;
	if ($line =~ /^Total /) {
		print "time: " . time . "\n";
	}
	if ($line =~ /^\s*[A-Z]/) {
		print $line;
		next;
	}
	my $bufcopy = $line;
	$bufcopy =~ s/^\s*//;
	my @elements = split(/\s+/, $bufcopy);
	if ($elements[3] != 0 || $elements[5] != 0 || $elements[7] != 0 || $elements[9] != 0) {
		print $line;
	}
}'
