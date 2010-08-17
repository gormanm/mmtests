#!/bin/bash

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot

. $SCRIPTDIR/common-cmdline-parser.sh

TITLES=
for SINGLE_KERNEL in $KERNEL; do
	REPORTDIR=$WORKINGDIR/vmr-createdelete-$SINGLE_KERNEL/noprofile

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

for MAPPING in anonmapping filemapping; do
	MAX_THREADS=`ls $WORKINGDIR/vmr-createdelete-$SINGLE_KERNEL/noprofile/createdelete-$MAPPING/results.* | wc -l`
	for NR_THREADS in `seq 1 $MAX_THREADS`; do
		PLOTS=
		for SINGLE_KERNEL in $KERNEL; do
			PLOTS="$PLOTS $WORKINGDIR/vmr-createdelete-$SINGLE_KERNEL/noprofile/createdelete-$MAPPING/results.$NR_THREADS"
		done

		$PLOT \
			--createdelete \
			--title "$ARCH createdelete files/sec comparison" \
			--format "postscript color" \
			--xlabel "File Size" \
			--ylabel "Time (seconds)" \
			--titles $TITLES \
			--output $OUTPUTDIR/createdelete-$MAPPING-$NR_THREADS-$NAME.ps \
			$PLOTS
			echo Generated createdelete-$MAPPING-$NR_THREADS-$NAME.ps
		done
done

#$PLOT \
#	--title "$ARCH fsmark files/sec comparison" \
#	--using "smooth bezier" \
#	--format "postscript color" \
#	--xlabel "Iteration" \
#	--ylabel "Files/sec" \
#	--titles $TITLES \
#	--output $OUTPUTDIR/fsmark-smooth-$NAME.ps \
#	$PLOTS
#	echo Generated fsmark-smooth-$NAME.ps
