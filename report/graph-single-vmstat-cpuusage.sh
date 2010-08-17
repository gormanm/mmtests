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
	awk "{print (\$1-$START)\" \"\$17\" \"\$18\" \"\$19\" \"\$20}" vmstat-$KERNEL-* > cpu-usage.plot-unsorted
	. $SCRIPTDIR/common-testname-markup.sh
else
	# Clear the markup as we cannot correlate with it reliability
	echo -n > /tmp/$NAME-extra

	echo -n > cpu-usage.plot-unsorted
	for TEST in $MMTESTS; do
		awk "{print ($COUNT+NR)\" \"\$13\" \"\$14\" \"\$15\" \"\$16}" vmstat-$KERNEL-$TEST >> cpu-usage.plot-unsorted
		THISCOUNT=`cat vmstat-$KERNEL-$TEST | wc -l`
		COUNT=$(($COUNT+$THISCOUNT))
	done
fi

sort -n cpu-usage.plot-unsorted > cpu-usage.plot
rm cpu-usage.plot-unsorted

$PLOT --cpu-usage \
	--title "$NAME $KERNEL CPU Usage" \
	--format "postscript color" \
	--extra /tmp/$NAME-extra \
	--dump \
	--output $OUTPUTDIR/cpu-usage-$NAME.ps \
	cpu-usage.plot > $OUTPUTDIR/cpu-usage-$NAME.gp
echo Generated cpu-usage-$NAME.ps
