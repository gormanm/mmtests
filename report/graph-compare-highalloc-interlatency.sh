#!/bin/bash

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
RAW_LATENCY=$SCRIPTDIR/raw-highalloc-latency

. $SCRIPTDIR/common-cmdline-parser.sh

TITLES=
for SINGLE_KERNEL in $KERNEL; do
	REPORTDIR=$WORKINGDIR/stress-highalloc-$SINGLE_KERNEL/noprofile
	XMIN=0
	XMAX=`cat $REPORTDIR/buddyinfo_at_fails-pass1.txt | grep ^Buddyinfo | wc -l`
	$RAW_LATENCY stats $REPORTDIR $XMIN $XMAX 1 > $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data

	cat $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data | awk '{print $1" "$3}' > $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data-min
	cat $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data | awk '{print $1" "$4}' > $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data-max
	cat $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data | awk '{print $1" "$5}' > $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data-mean
	cat $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data | awk '{print $1" "$6}' > $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data-stddev

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

for OP in mean max stddev; do
	case $OP in
		min)
			HEADING="Minimum Latency"
			;;
		max)
			HEADING="Worst Latency"
			;;
		mean)
			HEADING="Average Latency"
			;;
		stddev)
			HEADING="Variability"
			;;
	esac

	PLOTS=
	for SINGLE_KERNEL in $KERNEL; do
		PLOTS="$PLOTS $TMPDIR/highalloc-stats-$NAME-$SINGLE_KERNEL.data-$OP"
	done

	$PLOT \
		--title "$ARCH high alloc latency $HEADING comparison" \
		--format "postscript color" \
		--xlabel "Success Allocation (%)" \
		--ylabel "$HEADING" \
		--titles $TITLES \
		--output $OUTPUTDIR/highalloc-interlatency-$NAME-$OP.ps \
		$PLOTS
	#epstopdf highalloc-interlatency-$HOST-compaction-v8r8-$OP.ps
	echo Generated highalloc-interlatency-$NAME-$OP.ps
done
