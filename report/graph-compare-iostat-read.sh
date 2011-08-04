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

	ANY_TEST=`ls $WORKINGDIR/iostat-$SINGLE_KERNEL-* | head -1 | awk -F - '{print $NF}'`
	if [ ! -e $WORKINGDIR/iostat-$SINGLE_KERNEL-$ANY_TEST ]; then
		ANY_TEST=`ls $WORKINGDIR/iostat-$SINGLE_KERNEL-* | head -1 | awk -F - '{print $(NF-1)"-"$NF}'`
		if [ ! -e $WORKINGDIR/iostat-$SINGLE_KERNEL-$ANY_TEST ]; then
        		echo Cannot find records for $ANY_TEST in $WORKINGDIR/iostat-$SINGLE_KERNEL-$ANY_TEST
        		exit -1
		fi
	fi 

	# Is timestamp information available?
	head -1 iostat-$SINGLE_KERNEL-$ANY_TEST | grep -- -- > /dev/null
	if [ $? -eq 0 ]; then
		TIMESTAMPS=yes
		cat iostat-$SINGLE_KERNEL-* | grep -- "-- $IOSTAT_DEVICE " | awk "{print (\$1-$START)\" \"\$10}" > $TMPDIR/iostat-rbs-$NAME-$SINGLE_KERNEL.data-unsorted
	else
		echo -n > $TMPDIR/iostat-rbs-$NAME-$SINGLE_KERNEL.data-unsorted
		for TEST in $MMTESTS; do
			zcat iostat-$SINGLE_KERNEL-$TEST.gz | grep "^$IOSTAT_DEVICE " | awk "{print ($COUNT+NR)\" \"\$6}" >> $TMPDIR/iostat-rbs-$NAME-$SINGLE_KERNEL.data-unsorted
			THISCOUNT=`zcat iostat-$SINGLE_KERNEL-$TEST.gz | wc -l`
			COUNT=$(($COUNT+$THISCOUNT))
		done
	fi
	sort -n $TMPDIR/iostat-rbs-$NAME-$SINGLE_KERNEL.data-unsorted > $TMPDIR/iostat-rbs-$NAME-$SINGLE_KERNEL.data
	rm $TMPDIR/iostat-rbs-$NAME-$SINGLE_KERNEL.data-unsorted
	
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
	PLOTS="$PLOTS $TMPDIR/iostat-rbs-$NAME-$SINGLE_KERNEL.data"
done

$PLOT \
	--timeplot \
	--title "$ARCH IO Stat Read Sectors Comparison" \
	--extra $TMPDIR/$NAME-extra \
	--format "postscript color" \
	--ylabel "Sectors per Second" \
	--titles $TITLES \
	--output $OUTPUTDIR/iostat-rbs-comparison-$NAME.ps \
	$PLOTS
echo Generated iostat-rbs-comparison-$NAME.ps

$PLOT \
	--timeplot \
	--using "smooth bezier" \
	--extra $TMPDIR/$NAME-extra \
	--title "$ARCH IO Stat Read Sectors Comparison" \
	--format "postscript color" \
	--ylabel "Sectors per Second" \
	--titles $TITLES \
	--output $OUTPUTDIR/iostat-rbs-comparison-smooth-$NAME.ps \
	$PLOTS
echo Generated iostat-rbs-comparison-smooth-$NAME.ps
