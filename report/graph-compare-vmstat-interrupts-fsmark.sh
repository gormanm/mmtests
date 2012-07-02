#!/bin/bash

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh

TITLES=
for SINGLE_KERNEL in $KERNEL; do
	START=`head -1 $WORKINGDIR/tests-timestamp-$SINGLE_KERNEL | awk '{print $3}'`

	ANY_TEST=`echo $MMTESTS | awk '{print $1}'`
	if [ ! -e $WORKINGDIR/vmstat-$SINGLE_KERNEL-$ANY_TEST ]; then
        	echo Cannot find records for $ANY_TEST
        	exit -1
	fi 

	# Is timestamp information available?
	head -1 vmstat-$SINGLE_KERNEL-$ANY_TEST | grep -- -- > /dev/null
	if [ $? -eq 0 ]; then
		TIMESTAMPS=yes
		awk "{print (\$1-$START)\" \"\$16}" vmstat-$SINGLE_KERNEL-fsmark* > $TMPDIR/interrupt-stats-$NAME-$SINGLE_KERNEL.data-unsorted
	else
		# Clear the markup as we cannot correlate with it reliability
		echo -n > $TMPDIR/$NAME-extra
	
		echo -n > $TMPDIR/interrupt-stats-$NAME-$SINGLE_KERNEL.data-unsorted
		for TEST in fsmark; do
			awk "{print ($COUNT+NR)\" \"\$11}" vmstat-$SINGLE_KERNEL-$TEST >> $TMPDIR/interrupt-stats-$NAME-$SINGLE_KERNEL.data-unsorted
			THISCOUNT=`cat vmstat-$SINGLE_KERNEL-$TEST | wc -l`
			COUNT=$(($COUNT+$THISCOUNT))
		done
	fi
	sort -n $TMPDIR/interrupt-stats-$NAME-$SINGLE_KERNEL.data-unsorted > $TMPDIR/interrupt-stats-$NAME-$SINGLE_KERNEL.data
	rm $TMPDIR/interrupt-stats-$NAME-$SINGLE_KERNEL.data-unsorted
	
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
	PLOTS="$PLOTS $TMPDIR/interrupt-stats-$NAME-$SINGLE_KERNEL.data"
done

$PLOT \
	--timeplot \
	--title "$ARCH Interrupts comparison" \
	--format "postscript color" \
	--ylabel "Interrupts" \
	--titles $TITLES \
	--output $OUTPUTDIR/interrupt-comparison-fsmark-$NAME.ps \
	$PLOTS
echo Generated interrupt-comparison-fsmark-$NAME.ps

$PLOT \
	--timeplot \
	--smooth bezier \
	--title "$ARCH $HEADING" \
	--format "postscript color" \
	--ylabel "Interrupts" \
	--titles $TITLES \
	--output $OUTPUTDIR/interrupt-comparison-fsmark-smooth-$NAME.ps \
	$PLOTS
echo Generated interrupt-comparison-fsmark-smooth-$NAME.ps
