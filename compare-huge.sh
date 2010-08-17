#!/bin/bash

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
. $SCRIPTDIR/config

SUBKERNEL=-v1r1
FTRACE_ANALYSERS="mmtests-duration"
FTRACE_HELPER_VMSCAN=$LINUX_GIT/Documentation/trace/postprocess/trace-vmscan-postprocess.pl
FTRACE_HELPER_CONGESTION=$SCRIPTDIR/subreport/trace-congestion-postprocess.pl
NAS_EXTRACT=$SCRIPTDIR/subreport/nas-extract.sh
SPECCPU_EXTRACT=$SCRIPTDIR/subreport/speccpu-extract.sh
SPECJVM_EXTRACT=$SCRIPTDIR/subreport/specjvm-extract.sh
DIRLIST=

TOPLEVEL=noprofile
if [ "$1" != "" ]; then
	TOPLEVEL=$1
fi

gendirlist() {
	PREFIX=$1

	DIRLIST=
	for SUBLIST in $PREFIX $PREFIX-large$SUBKERNEL $PREFIX-dynlarge$SUBKERNEL; do
		if [ -e $SUBLIST ]; then
			DIRLIST="$DIRLIST $SUBLIST"
		fi
	done
}
		
printheader() {
	printf "%-14s" " "
	for BACKING_TYPE in $BACKING_TYPES; do
		printf "%18s" $BACKING_TYPE
	done
	echo
}

for SUBREPORT in vmr-stream nas-ser nas-omp sysbench speccpu specjvm specomp; do
	if [ -e $SUBREPORT$SUBKERNEL ]; then
		if [ -e $SCRIPTDIR/subreport/largecompare-$SUBREPORT ]; then
			. $SCRIPTDIR/subreport/largecompare-$SUBREPORT
		fi

		#for FTRACE_ANALYSER in $FTRACE_ANALYSERS; do
		#	FTRACE_TEST=$SUBREPORT
		#	. $SCRIPTDIR/subreport/$FTRACE_ANALYSER
		#done
	fi
done
