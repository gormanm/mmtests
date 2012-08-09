#!/bin/bash

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
. $SCRIPTDIR/config

KERNEL_BASE="2.6.38-mainline"
KERNEL_COMPARE="2.6.39-mainline"
FTRACE_ANALYSERS="mmtests-duration mmtests-vmstat"
FTRACE_HELPER_PAGEALLOC=$LINUX_GIT/Documentation/trace/postprocess/trace-pagealloc-postprocess.pl
FTRACE_HELPER_VMSCAN=$LINUX_GIT/subreport/trace-vmscan-postprocess.pl
FTRACE_HELPER_CONGESTION=$SCRIPTDIR/subreport/trace-congestion-postprocess.pl
TIMESTAMP_HELPER=$SCRIPTDIR/subreport/teststimestamp-extract
DIRLIST=

TMPDIR=`mktemp`
rm $TMPDIR
mkdir $TMPDIR

TOPLEVEL=noprofile
if [ "$1" != "" ]; then
	TOPLEVEL=$1
fi

if [ ! -e tests-timestamp-$KERNEL_BASE ]; then
	TEMP_KERNEL_BASE=
	TEMP_KERNEL_COMPARE=
	for KERNEL in $KERNEL_COMPARE; do
		if [ -e tests-timestamp-$KERNEL ]; then
			if [ "$TEMP_KERNEL_BASE" = "" ]; then
				TEMP_KERNEL_BASE=$KERNEL
			fi
			TEMP_KERNEL_COMPARE="$TEMP_KERNEL_COMPARE $KERNEL"
		fi
		KERNEL_BASE=$TEMP_KERNEL_BASE
		KERNEL_COMPARE=$TEMP_KERNEL_COMPARE
	done
fi

gendirlist() {
	PREFIX=$1

	DIRLIST=
	for DIRNAME in $KERNEL_BASE $KERNEL_COMPARE; do
		for SUBDIR in `ls -d $PREFIX-$DIRNAME 2> /dev/null`; do
			DIRLIST="$DIRLIST $SUBDIR"
		done
	done
}
		
printheader() {
printf "            "
for DIR in $DIRLIST; do
	NAME=`echo $DIR | awk -F - '{print $(NF-3)"-"$(NF-2)}' 2> /dev/null`
	if [ "$NAME" = "" ]; then
		NAME="-"
	fi
	printf "%18s" $NAME
done
echo
printf "            "
for DIR in $DIRLIST; do
	NAME=`echo $DIR | awk -F - '{print $(NF-1)"-"$NF}'`
	printf "%18s" $NAME
done
echo
}

SIMUL=`ls *mmtestsimul* 2> /dev/null`
for SUBREPORT in kernbench parallelio starve pagealloc tiobench dbench3 dbench4 multibuild fsmark-single fsmark-threaded postmark iozone netperf-udp netperf-tcp tbench4 lmbench hackbench-pipes hackbench-sockets pipetest vmr-createdelete vmr-cacheeffects ffsb vmr-aim9 vmr-stream sysbench largecopy largedd simple-writeback rsyncresidency ddresidency highalloc stress-highalloc thpavail pft micro; do
	if [ -e $SUBREPORT-$KERNEL_BASE ]; then
		echo ===BEGIN $SUBREPORT
		INPUTS=
		TITLES=
		CLIENTS=
		ORDERS=
		if [ "$SIMUL" = "" -a -e $SCRIPTDIR/subreport/$SUBREPORT ]; then
			. $SCRIPTDIR/subreport/$SUBREPORT
		fi

		for FTRACE_ANALYSER in $FTRACE_ANALYSERS; do
			FTRACE_TEST=$SUBREPORT
			. $SCRIPTDIR/subreport/$FTRACE_ANALYSER
			echo
		done
		echo ===END $SUBREPORT
		if [ "$INPUTS" != "" ]; then
			echo ===INPUTS $SUBREPORT : $INPUTS
		fi
		if [ "$INPUTS" != "" ]; then
			echo ===TITLES $SUBREPORT : $TITLES
		fi
		if [ "$CLIENTS" != "" ]; then
			echo ===CLIENTS $SUBREPORT : $CLIENTS
		fi
		if [ "$ORDERS" != "" ]; then
			echo ===ORDERS $SUBREPORT : $ORDERS
		fi
		if [ "$SIMUL" != "" ]; then
			rm -rf $TMPDIR
			exit
		fi
	fi
done

echo -n "===TIMESTAMPS : "
for KERNEL in $KERNEL_BASE $KERNEL_COMPARE; do
	echo -n "`pwd`/tests-timestamp-$KERNEL "
done
echo

rm -rf $TMPDIR
