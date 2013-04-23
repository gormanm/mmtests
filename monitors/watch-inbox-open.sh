#!/bin/bash
#
# This monitor acts like a crude version of a mail reader that opens all mails
# in a maildir folder and reads through them
#
# Copyright Mel Gorman 2013

# Extract the inbox open program
TEMPFILE=`mktemp`
LINECOUNT=`wc -l $0 | awk '{print $1}'`
PSTART=`grep -n "BEGIN PERL FILE" $0 | tail -1 | awk -F : '{print $1}'`
tail -$(($LINECOUNT-$PSTART)) $0 | grep -v "^###" > $TEMPFILE.pl
chmod u+x $TEMPFILE.pl

# Use temporary directory if available
if [ "$SHELLPACK_TEMP" != "" ]; then
	mkdir -p $SHELLPACK_TEMP || exit -1
	cd $SHELLPACK_TEMP || exit -1
fi

# Use or fetch a suitable maildir
if [ "$MONITOR_INBOX_OPEN_MAILDIR" = "" ]; then
	if [ "$MONITOR_INBOX_OPEN_SOURCE" = "" ]; then
		echo No MONITOR_INBOX_OPEN_MAILDIR or MONITOR_INBOX_OPEN_SOURCE specified
		exit -1
	fi

	TARFILE=maildir.tar.gz
	wget -q -O $TARFILE $MONITOR_INBOX_OPEN_SOURCE || die Failed to wget $MONITOR_INBOX_OPEN_SOURCE
	tar -xf $TARFILE || die Failed to unpack maildir tar.gz
	DST_DIR=`tar tf $TARFILE | head -n 1 | awk -F / '{print $1}'`
	mv $DST_DIR maildir-inbox-open
	rm $TARFILE
	export MONITOR_INBOX_OPEN_MAILDIR=`pwd`/maildir-inbox-open
fi

# Start the inbox open script
$TEMPFILE.pl &
INBOX_OPEN=$!

# Handle being shutdown
EXITING=0
shutdown_read() {
	kill -9 $INBOX_OPEN
	rm $TEMPFILE.pl
	if [ "$MONITOR_INBOX_OPEN_SOURCE" != "" ]; then
		rm -rf maildir-inbox-open
		if [ "$SHELLPACK_TEMP" != "" ]; then
			cd /
			rm -rf $SHELLPACK_TEMP
		fi
	fi
	EXITING=1
	exit 0
}
	
trap shutdown_read SIGTERM
trap shutdown_read SIGINT

while [ 1 ]; do
	sleep 5

	# Check if we should shutdown
	if [ $EXITING -eq 1 ]; then
		exit 0
	fi

	# Check if the inbox open program exited abnormally
	ps -p $INBOX_OPEN > /dev/null
	if [ $? -ne 0 ]; then
		echo inbox open program exited abnormally
		exit -1
	fi
done

==== BEGIN PERL FILE ====
#!/usr/bin/perl

use strict;
use File::Find;

my @files;

sub is_file {
	push @files, $File::Find::name if -f;
}

my @emails;
my $count;

my $maildir = $ENV{"MONITOR_INBOX_OPEN_MAILDIR"};
if ($maildir eq "") {
	die("No MONITOR_INBOX_OPEN_MAILDIR specified");
}

chdir("$maildir") || die("Failed to chdir $maildir");
find(\&is_file, '.');

while (1) {
	open(OUTPUT, ">/proc/sys/vm/drop_caches");
	print OUTPUT "3";
	close(OUTPUT);
	my $start = time;
	foreach my $file (@files) {
		my %mail_details;
		my $reading_header = 1;

		open(INPUT, $file) || die("Failed to open $file");
		my @stat_details = stat INPUT;
		$mail_details{"stat"} = \@stat_details;
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			$reading_header = 0 if ($line =~ /^$/);

			chomp($line);
			my ($key, $value) = split(/:/, $line, 2);

			if ($reading_header &&
			    $key eq "Date" ||
			    $key eq "Subject" ||
			    $key eq "From") {
				$mail_details{$key} = $value
			}
		
		}
		close(INPUT);
		push @emails, \%mail_details;

		$count++;
		if ($count == 1000) {
			$count = 0;
			my $end = time;

			printf "%lu %lu\n", $end, $end - $start;
	
			$start = $end;
		}
	}
}
