#!/bin/bash

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
RAW_LATENCY=$SCRIPTDIR/raw-highalloc-latency

. $SCRIPTDIR/common-cmdline-parser.sh

TITLES=
for SINGLE_KERNEL in $KERNEL; do
	REPORTDIR=$WORKINGDIR/fsmark-$SINGLE_KERNEL/noprofile

	STARTLINE=`grep -n ^FSUse $REPORTDIR/fsmark.log | awk -F : '{print $1}'`
	LENGTH=`cat $REPORTDIR/fsmark.log | wc -l`
	tail -$(($LENGTH-$STARTLINE)) $REPORTDIR/fsmark.log > $REPORTDIR/fsmark-stripped.log

	awk '{print NR" "$4}' $REPORTDIR/fsmark-stripped.log > $TMPDIR/fsmark-$NAME-$SINGLE_KERNEL.data

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
	PLOTS="$PLOTS $TMPDIR/fsmark-$NAME-$SINGLE_KERNEL.data"
done

$PLOT \
	--title "$ARCH fsmark files/sec comparison" \
	--format "postscript color" \
	--xlabel "Iteration" \
	--ylabel "Files/sec" \
	--titles $TITLES \
	--output $OUTPUTDIR/fsmark-$NAME.ps \
	$PLOTS
	echo Generated fsmark-$NAME.ps
