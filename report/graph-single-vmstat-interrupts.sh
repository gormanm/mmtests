#!/bin/bash
# Plot CPU usage over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config

. $SCRIPTDIR/common-cmdline-parser.sh

ANY_TEST=`echo $MMTESTS | awk '{print $1}'`
if [ ! -e vmstat-$KERNEL-$ANY_TEST ]; then
	echo Cannot find records for $ANY_TEST
	exit -1
fi

START=`head -1 tests-timestamp-$KERNEL | awk '{print $3}'`
COUNT=0

# Is timestamp information available?
head -1 vmstat-$KERNEL-$ANY_TEST | grep -- -- > /dev/null
if [ $? -eq 0 ]; then
	TIMESTAMPS=yes
	awk "{print (\$1-$START)\" \"\$16}" vmstat-$KERNEL-* > interrupts.plot-unsorted
	. $SCRIPTDIR/common-testname-markup.sh
else
	# Clear the markup as we cannot correlate with it reliability
	echo -n > /tmp/$NAME-extra

	echo -n > interrupts.plot-unsorted
	for TEST in $MMTESTS; do
		awk "{print ($COUNT+NR)\" \"\$11}" vmstat-$KERNEL-$TEST >> interrupts.plot-unsorted
		THISCOUNT=`cat vmstat-$KERNEL-$TEST | wc -l`
		COUNT=$(($COUNT+$THISCOUNT))
	done
fi

sort -n interrupts.plot-unsorted > interrupts.plot
rm interrupts.plot-unsorted

$PLOT --timeplot \
	--title "$NAME $KERNEL Interrupts" 
	--ylabel "Interrupts" \
	--format "postscript color" \
	--titles "interrupts" \
	--extra /tmp/$NAME-extra \
	--dump \
	--output $OUTPUTDIR/interrupts-$NAME.ps \
	interrupts.plot > $OUTPUTDIR/interrupts-$NAME.gp
echo Generated interrupts-$NAME.ps
