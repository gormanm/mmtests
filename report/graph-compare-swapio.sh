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
		awk "{print (\$1-$START)\" \"(\$12+\$13)}" vmstat-$SINGLE_KERNEL-* > $TMPDIR/swapio-$NAME-$SINGLE_KERNEL.data-unsorted
	else
		echo -n > $TMPDIR/swapio-$NAME-$SINGLE_KERNEL.data-unsorted
		for TEST in $MMTESTS; do
			awk "{print ($COUNT+NR)\" \"(\$7+\$8)}" vmstat-$SINGLE_KERNEL-$TEST >> $TMPDIR/swapio-$NAME-$SINGLE_KERNEL.data-unsorted
			THISCOUNT=`cat vmstat-$SINGLE_KERNEL-$TEST | wc -l`
			COUNT=$(($COUNT+$THISCOUNT))
		done
	fi
	sort -n $TMPDIR/swapio-$NAME-$SINGLE_KERNEL.data-unsorted > $TMPDIR/swapio-$NAME-$SINGLE_KERNEL.data
	rm $TMPDIR/swapio-$NAME-$SINGLE_KERNEL.data-unsorted
	
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
	PLOTS="$PLOTS $TMPDIR/swapio-$NAME-$SINGLE_KERNEL.data"
done

$PLOT \
	--timeplot \
	--title "$NAME Swap IO Comparison" \
	--extra $TMPDIR/$NAME-extra \
	--format "postscript color" \
	--ylabel "Swap Page IO" \
	--titles $TITLES \
	--output $OUTPUTDIR/swapio-comparison-$NAME.ps \
	$PLOTS
echo Generated swapio-comparison-$NAME.ps

$PLOT \
	--timeplot \
	--smooth bezier \
	--extra $TMPDIR/$NAME-extra \
	--title "$NAME Swap IO Comparison" \
	--format "postscript color" \
	--ylabel "Swap Page IO" \
	--titles $TITLES \
	--output $OUTPUTDIR/swapio-comparison-smooth-$NAME.ps \
	$PLOTS
echo Generated swapio-comparison-smooth-$NAME.ps
