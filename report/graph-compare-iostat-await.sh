#!/bin/bash

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh

if [ "$IOSTAT_DEVICE" = "" ]; then
	IOSTAT_DEVICE=sda
fi

for SINGLE_KERNEL in $KERNEL; do
	FIRST_KERNEL=$SINGLE_KERNEL
	break
done

COPY=$KERNEL
KERNEL=$FIRST_KERNEL
START=`head -1 tests-timestamp-$FIRST_KERNEL | awk '{print $3}'`
. $SCRIPTDIR/common-testname-markup.sh
KERNEL=$COPY

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
		cat iostat-$SINGLE_KERNEL-* | grep -- "-- $IOSTAT_DEVICE " | awk "{print (\$1-$START)\" \"\$14}" > $TMPDIR/iostat-await-$NAME-$SINGLE_KERNEL.data-unsorted
	else
		echo -n > $TMPDIR/iostat-await-$NAME-$SINGLE_KERNEL.data-unsorted
		for TEST in $MMTESTS; do
			zcat iostat-$SINGLE_KERNEL-$TEST.gz | grep "^$IOSTAT_DEVICE " | awk "{print ($COUNT+NR)\" \"\$10}" >> $TMPDIR/iostat-await-$NAME-$SINGLE_KERNEL.data-unsorted
			THISCOUNT=`zcat iostat-$SINGLE_KERNEL-$TEST.gz | wc -l`
			COUNT=$(($COUNT+$THISCOUNT))
		done
	fi
	sort -n $TMPDIR/iostat-await-$NAME-$SINGLE_KERNEL.data-unsorted > $TMPDIR/iostat-await-$NAME-$SINGLE_KERNEL.data
	rm $TMPDIR/iostat-await-$NAME-$SINGLE_KERNEL.data-unsorted
	
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
	PLOTS="$PLOTS $TMPDIR/iostat-await-$NAME-$SINGLE_KERNEL.data"
done

$PLOT \
	--timeplot \
	--title "$ARCH IO Stat Average Wait Comparison" \
	--extra $TMPDIR/$NAME-extra \
	--format "postscript color" \
	--ylabel "Average Wait (ms)" \
	--titles $TITLES \
	--output $OUTPUTDIR/iostat-await-comparison-$NAME.ps \
	$PLOTS
echo Generated iostat-await-comparison-$NAME.ps

$PLOT \
	--timeplot \
	--using "smooth bezier" \
	--extra $TMPDIR/$NAME-extra \
	--title "$ARCH IO Stat Average Wait Comparison" \
	--format "postscript color" \
	--ylabel "Average wait (ms)" \
	--yrange 0:100 \
	--titles $TITLES \
	--output $OUTPUTDIR/iostat-await-comparison-smooth-$NAME.ps \
	$PLOTS
echo Generated iostat-await-comparison-smooth-$NAME.ps
