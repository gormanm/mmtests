#!/bin/bash

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh
. $SCRIPTDIR/common-testname-markup.sh

TITLES=
for SINGLE_KERNEL in $KERNEL; do
	START=`head -1 $WORKINGDIR/tests-timestamp-$SINGLE_KERNEL | awk '{print $3}'`

	ANY_TEST=`ls $WORKINGDIR/vmstat-$SINGLE_KERNEL-* | head -1 | awk -F - '{print $NF}'`
	if [ ! -e $WORKINGDIR/vmstat-$SINGLE_KERNEL-$ANY_TEST ]; then
		ANY_TEST=`ls $WORKINGDIR/vmstat-$SINGLE_KERNEL-* | head -1 | awk -F - '{print $(NF-1)"-"$NF}'`
		if [ ! -e $WORKINGDIR/vmstat-$SINGLE_KERNEL-$ANY_TEST ]; then
        		echo Cannot find records for $ANY_TEST in $WORKINGDIR/vmstat-$SINGLE_KERNEL-$ANY_TEST
        		exit -1
		fi
	fi 

	# Is timestamp information available?
	head -1 vmstat-$SINGLE_KERNEL-$ANY_TEST | grep -- -- > /dev/null
	if [ $? -eq 0 ]; then
		TIMESTAMPS=yes
		awk "{print (\$1-$START)\" \"\$3}" vmstat-$SINGLE_KERNEL-* > $TMPDIR/vmstat-latency-$NAME-$SINGLE_KERNEL.data-unsorted
	else
		echo ERROR: Timestamp and latency information unavailable
		exit
	fi
	sort -n $TMPDIR/vmstat-latency-$NAME-$SINGLE_KERNEL.data-unsorted > $TMPDIR/vmstat-latency-$NAME-$SINGLE_KERNEL.data
	rm $TMPDIR/vmstat-latency-$NAME-$SINGLE_KERNEL.data-unsorted
	
	if [ "$TITLES" != "" ]; then
		TITLES=$TITLES,
	fi
	TITLES="$TITLES$SINGLE_KERNEL"
done
if [ "$FORCE_TITLES" != "" ]; then
	TITLES=$FORCE_TITLES
fi
if [ "$ARCH" = "" ]; then
	ARCH=$NAME
fi

PLOTS=
for SINGLE_KERNEL in $KERNEL; do
	PLOTS="$PLOTS $TMPDIR/vmstat-latency-$NAME-$SINGLE_KERNEL.data"
done

$PLOT \
	--timeplot \
	--title "$ARCH VMStat Latency Update Comparison" \
	--extra $TMPDIR/$NAME-extra \
	--format "postscript color" \
	--ylabel "Update Latency (seconds)" \
	--titles $TITLES \
	--output $OUTPUTDIR/vmstat-latency-comparison-$NAME.ps \
	$PLOTS
echo Generated vmstat-latency-comparison-$NAME.ps

$PLOT \
	--timeplot \
	--using "smooth bezier" \
	--extra $TMPDIR/$NAME-extra \
	--title "$ARCH VMStat Latency Update Comparison" \
	--format "postscript color" \
	--ylabel "Update Latency (seconds)" \
	--titles $TITLES \
	--output $OUTPUTDIR/vmstat-latency-comparison-smooth-$NAME.ps \
	$PLOTS
echo Generated vmstat-latency-comparison-smooth-$NAME.ps
