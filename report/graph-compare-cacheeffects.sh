#!/bin/bash

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot

. $SCRIPTDIR/common-cmdline-parser.sh

TITLES=
for SINGLE_KERNEL in $KERNEL; do
	REPORTDIR=$WORKINGDIR/vmr-cacheeffects-$SINGLE_KERNEL/noprofile

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

for MAPPING in seq-smallpages seq-largepages rand-smallpages rand-largepages; do
	if [ ! -e $WORKINGDIR/vmr-cacheeffects-$SINGLE_KERNEL/noprofile/cacheeffects-$MAPPING ]; then
		continue
	fi

	ARRAYSIZES=
	for FILENAME in `ls $WORKINGDIR/vmr-cacheeffects-$SINGLE_KERNEL/noprofile/cacheeffects-$MAPPING/results.*`; do
		ARRAYSIZES="$ARRAYSIZES `basename $FILENAME | sed -e 's/results.//'`"
	done
	for ARRAYSIZE in $ARRAYSIZES; do
		PLOTS=
		for SINGLE_KERNEL in $KERNEL; do
			PLOTS="$PLOTS $WORKINGDIR/vmr-cacheeffects-$SINGLE_KERNEL/noprofile/cacheeffects-$MAPPING/results.$ARRAYSIZE"
		done

		$PLOT \
			--cacheeffects \
			--title "$ARCH cacheeffects node traversal comparison" \
			--format "postscript color" \
			--titles $TITLES \
			--output $OUTPUTDIR/cacheeffects-$MAPPING-$ARRAYSIZE-$NAME.ps \
			$PLOTS
			echo Generated cacheeffects-$MAPPING-$ARRAYSIZE-$NAME.ps
		done
done
