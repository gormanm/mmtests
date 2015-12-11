#!/bin/bash

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/config

KERNEL_BASE=
KERNEL_COMPARE=
KERNEL_EXCLUDE=
POSTSCRIPT_OUTPUT=no

while [ "$1" != "" ]; do
	case $1 in
	--format)
		FORMAT=$2
		FORMAT_CMD="--format $FORMAT"
		shift 2
		;;
	--output-dir)
		OUTPUT_DIRECTORY=$2
		shift 2
		;;
	--baseline)
		KERNEL_BASE=$2
		shift 2
		;;
	--compare)
		if [ -z "$KERNEL_COMPARE" ]; then
			KERNEL_COMPARE="$2"
		else
			KERNEL_COMPARE="$KERNEL_COMPARE $2"
		fi
		shift 2
		;;
	--result-dir)
		cd "$2" || die Result directory does not exist or is not directory
		shift 2
		;;
	--sort-version)
		SORT_VERSION=yes
		shift
		;;
	--R)
		USE_R="--R"
		shift
		;;
	--plot-details)
		PLOT_DETAILS="yes"
		shift
		;;
	--iterations)
		ITERATIONS="$1 $2"
		FIRST_ITERATION_PREFIX="1/"
		shift 2
		;;
	*)
		echo Unrecognised argument: $1 1>&2
		shift
		;;
	esac
done


# Do Not Litter
cleanup() {
	if [ "$R_TMPDIR" != "" -a -d $R_TMPDIR ]; then
		rm -rf $R_TMPDIR
	fi
	exit
}

if [ "$USE_R" != "" ]; then
	export R_TMPDIR="`mktemp -d`"
	trap cleanup EXIT
	trap cleanup INT
	trap cleanup TERM
fi

FORMAT_CMD=
if [ "$FORMAT" != "" ]; then
	FORMAT_CMD="--format $FORMAT"
fi
if [ "$OUTPUT_DIRECTORY" != "" -a ! -e "$OUTPUT_DIRECTORY" ]; then
	mkdir -p $OUTPUT_DIRECTORY
fi
if [ "$OUTPUT_DIRECTORY" != "" -a ! -d "$OUTPUT_DIRECTORY" ]; then
	echo Output directory is not a directory
	exit -1
fi

if [ `ls "$FIRST_ITERATION_PREFIX"tests-timestamp-* 2> /dev/null | wc -l` -eq 0 ]; then
	die This does not look like a mmtests results directory
fi

if [ -n "$KERNEL_BASE" ]; then
	for KERNEL in $KERNEL_COMPARE $KERNEL_BASE; do
		if [ ! -e "$FIRST_ITERATION_PREFIX"tests-timestamp-$KERNEL ]; then
			die "Cannot find results for kernel '$KERNEL'."
		fi
	done
else
	if [ -n "$KERNEL_COMPARE" ]; then
		die "Specifying --compare without --baseline is invalid!"
	fi
fi

# Build a list of kernels
if [ "$KERNEL_BASE" != "" ]; then
	KERNEL_LIST=$KERNEL_BASE
	for KERNEL in $KERNEL_COMPARE; do
		KERNEL_LIST=$KERNEL_LIST,$KERNEL
	done
else
	[ -n "$ITERATIONS" ] && pushd $FIRST_ITERATION_PREFIX > /dev/null
	for KERNEL in `grep -H ^start tests-timestamp-* | awk -F : '{print $4" "$1}' | sort -n | awk '{print $2}' | sed -e 's/tests-timestamp-//'`; do
		EXCLUDE=no
		for TEST_KERNEL in $KERNEL_EXCLUDE; do
			if [ "$TEST_KERNEL" = "$KERNEL" ]; then
				EXCLUDE=yes
			fi
		done
		if [ "$EXCLUDE" = "no" ]; then
			if [ "$KERNEL_BASE" = "" ]; then
				KERNEL_BASE=$KERNEL
				KERNEL_LIST=$KERNEL
			else
				KERNEL_LIST="$KERNEL_LIST,$KERNEL"
			fi
		fi
	done
	[ -n "$ITERATIONS" ] && popd > /dev/null
fi

if [ "$SORT_VERSION" = "yes" ]; then
	LIST_SORT=$KERNEL_LIST
	KERNEL_LIST=
	KERNEL_BASE=
	for MAJOR in `echo $LIST_SORT | sed -e 's/,/\n/g' | awk -F . '{print $1}' | sort -n | uniq`; do
		for KERNEL in `echo $LIST_SORT | sed -e 's/,/\n/g' | sort -t . -k2 -n | grep ^$MAJOR.`; do
			if [ "$KERNEL_BASE" = "" ]; then
				KERNEL_BASE=$KERNEL
				KERNEL_LIST=$KERNEL
			else
				KERNEL_LIST="$KERNEL_LIST,$KERNEL"
			fi
		done
	done
fi

KERNEL_LIST_ITER=`echo $KERNEL_LIST | sed -e 's/,/ /g'`

plain() {
	IMG_SRC=$1
	if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
		 echo -n "  <td><a href=\"$IMG_SRC.ps.gz\"><img src=\"$IMG_SRC.png\"></a></td>"
	else
		 echo -n "  <td><img src=\"$IMG_SRC.png\"></td>"
	fi
}

plain_alone() {
	IMG_SRC=$1
	if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
		echo -n "  <td colspan=4><a href=\"$IMG_SRC.ps.gz\"><img src=\"$IMG_SRC.png\"></a></td>"
	else
		echo -n "  <td colspan=4><img src=\"$IMG_SRC.png\"></td>"
	fi
}

smoothover() {
	IMG_SRC=$1
	IMG_SMOOTH=$1-smooth
	if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
		echo -n "  <td><a href=\"$IMG_SMOOTH.ps.gz\"><img src=\"$IMG_SRC.png\" onmouseover=\"this.src='$IMG_SMOOTH.png'\" onmouseout=\"this.src='$IMG_SRC.png'\"></a></td>"
	else
		echo -n "  <td><img src=\"$IMG_SRC.png\" onmouseover=\"this.src='$IMG_SMOOTH.png'\" onmouseout=\"this.src='$IMG_SRC.png'\"></td>"
	fi
}

generate_latency_table() {
	LATTYPE="$1"
	if [ `ls $LATTYPE-$KERNEL_BASE-* 2> /dev/null | wc -l` -gt 0 ]; then
		if [ `cat $LATTYPE-$KERNEL_BASE-* | wc -l` -gt 50000 ]; then
			GRANULARITY="--sub-heading batch=100"
		fi
		if [ "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			echo "<table class=\"resultsGraphs\">"
		fi
		eval $COMPARE_CMD $GRANULARITY                --print-monitor $LATTYPE
		echo
		eval $COMPARE_CMD --sub-heading breakdown=100 --print-monitor $LATTYPE
		if [ "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			echo "</table>"
		fi
	fi
}

generate_latency_graph()
{
	LATTYPE="$1"
	LATSTRING="$2"
	if [ `ls $LATTYPE-$KERNEL_BASE-* 2> /dev/null | wc -l` -gt 0 ]; then
		eval $GRAPH_PNG $GRANULARITY --title "$LATSTRING" --print-monitor $LATTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$LATTYPE.png
		eval $GRAPH_PNG $GRANULARITY --title "$LATSTRING" --print-monitor $LATTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$LATTYPE-smooth.png --smooth
		if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
			eval $GRAPH_PSC $GRANULARITY --title "$LATSTRING" --print-monitor $LATTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$LATTYPE.ps
			eval $GRAPH_PSC $GRANULARITY --title "$LATSTRING" --print-monitor $LATTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$LATTYPE-smooth.ps --smooth
		fi
		smoothover graph-$SUBREPORT-$LATTYPE
	fi
}

cat $SCRIPTDIR/shellpacks/common-header-$FORMAT 2> /dev/null
for SUBREPORT in `grep "test begin :: " "$FIRST_ITERATION_PREFIX"tests-timestamp-$KERNEL_BASE | awk '{print $4}'`; do
	EXTRACT_CMD="extract-mmtests.pl -d . -b $SUBREPORT" 
	COMPARE_CMD="compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD"
	COMPARE_BARE_CMD="compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST"
	COMPARE_R_CMD="compare-mmtests-R.sh -d . $ITERATIONS -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD"
	GRAPH_PNG="graph-mmtests.sh -d . -b $SUBREPORT -n $KERNEL_LIST $USE_R --format png"
	if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
		GRAPH_PSC="graph-mmtests.sh -d . -b $SUBREPORT -n $KERNEL_LIST $USE_R --format \"postscript color solid\""
	else
		GRAPH_PSC="#"
	fi
	echo
	if [ "$FORMAT" = "html" ]; then
		echo "<a name="$SUBREPORT">"
	fi
	case $SUBREPORT in
	dbench4)
		echo $SUBREPORT Overall Throughput
		$COMPARE_CMD
		echo
		echo $SUBREPORT Latency
		compare-mmtests.pl -d . -b dbench4latency -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Per-VFS Operation latency Latency
		compare-mmtests.pl -d . -b dbench4opslatency -n $KERNEL_LIST $FORMAT_CMD
		;;
	dbt5-bench)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo

		echo $SUBREPORT Latency
		compare-mmtests.pl -d . -b dbt5latency -n $KERNEL_LIST $FORMAT_CMD
		echo

		echo $SUBREPORT Execution time
		compare-mmtests.pl -d . -b dbt5exectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	dvdstore)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Time
		compare-mmtests.pl -d . -b dvdstoreexectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	ebizzy)
		echo $SUBREPORT Overall Throughput
		$COMPARE_CMD
		echo
		echo $SUBREPORT Per-thread
		compare-mmtests.pl -d . -b ebizzythread -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Thread spread
		compare-mmtests.pl -d . -b ebizzyrange -n $KERNEL_LIST $FORMAT_CMD
		;;
	fsmark-single|fsmark-threaded)
		echo $SUBREPORT
		$COMPARE_CMD
		echo
		echo $SUBREPORT App Overhead
		compare-mmtests.pl -d . -b ${SUBREPORT}overhead -n $KERNEL_LIST $FORMAT_CMD
		;;
	johnripper)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo

		echo $SUBREPORT User/System CPU time
		compare-mmtests.pl -d . -b johnripperexectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	loopdd)
		echo $SUBREPORT Throughput
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT DD-Time
		eval $COMPARE_CMD --sub-heading ddtime
		echo
		echo $SUBREPORT CPU-Time
		eval $COMPARE_CMD --sub-heading elapsed
		;;
	mediawikibuild)
		echo $SUBREPORT WikiMedia import pages/sec
		eval $COMPARE_CMD

		echo
		echo $SUBREPORT Data import times
		compare-mmtests.pl -d . -b mediawikibuildloadtime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	parallelio)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Background IO
		compare-mmtests.pl -d . -b parallelioio -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Swap totals
		compare-mmtests.pl -d . -b parallelioswap -n $KERNEL_LIST $FORMAT_CMD
		;;
	pft)
		echo $SUBREPORT timings
		compare-mmtests.pl -d . -b pfttime -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT faults
		eval $COMPARE_CMD
		;;
	pgbench)
		echo $SUBREPORT Initialisation
		compare-mmtests.pl -d . -b pgbenchloadtime -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		compare-mmtests.pl -d . -b pgbenchstalls -n $KERNEL_LIST $FORMAT_CMD > /tmp/pgbench-$$
		TEST=`grep MinStall-1 /tmp/pgbench-$$ | grep -v nan`
		if [ "$TEST" != "" ]; then
			echo
			echo $SUBREPORT Stalls
			cat /tmp/pgbench-$$
		fi
		rm /tmp/pgbench-$$
		echo
		echo $SUBREPORT Time
		compare-mmtests.pl -d . -b pgbenchexectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	specjvm)
		echo $SUBREPORT
		eval $COMPARE_CMD
		;;
	specjbb)
		echo $SUBREPORT
		$COMPARE_CMD
		echo $SUBREPORT Peaks
		compare-mmtests.pl -d . -b specjbbpeak -n $KERNEL_LIST $FORMAT_CMD
		;;
	stockfish)
		echo $SUBREPORT Nodes/sec
		compare-mmtests.pl -d . -b stockfish -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Execution time
		compare-mmtests.pl -d . -b stockfishtime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	stutter)
		echo $SUBREPORT
		$COMPARE_CMD
		echo
		echo $SUBREPORT estimated write speed
		compare-mmtests.pl -d . -b stuttercalibrate -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT parallel write throughput
		compare-mmtests.pl -d . -b stutterthroughput -n $KERNEL_LIST $FORMAT_CMD
		;;
	sysbench)
		echo $SUBREPORT Initialisation
		compare-mmtests.pl -d . -b sysbenchloadtime -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Time
		compare-mmtests.pl -d . -b sysbenchexectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	thpscale)
		echo $SUBREPORT Fault Latencies
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Percentage Faults Huge
		compare-mmtests.pl -d . -b thpscalecounts -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	tiobench)
		echo $SUBREPORT Throughput
		$COMPARE_CMD
		echo
		echo $SUBREPORT average and max operation latencies
		compare-mmtests.pl -d . -b tiobenchlatency -n $KERNEL_LIST $FORMAT_CMD
		;;
	*)
		echo $SUBREPORT
		# Try R if requested, fallback to perl when datatype is unsupported
		if [ "$USE_R" != "" ]; then
			eval $COMPARE_R_CMD
		else
			false
		fi || eval $COMPARE_CMD
	esac
	echo
	eval $COMPARE_CMD --print-monitor duration
	echo
	eval $COMPARE_CMD --print-monitor mmtests-vmstat

	TEST=
	if [ `ls iostat-* 2> /dev/null | wc -l` -gt 0 ]; then
		eval $COMPARE_BARE_CMD --print-monitor iostat 2> /dev/null > /tmp/iostat-$$
		TEST=`head -4 /tmp/iostat-$$ | tail -1 | awk '{print $3}' | cut -d. -f1`
	fi
	if [ "$TEST" != "" ] && [ "$TEST" != "nan" ] && [ $TEST -gt 5 ]; then
		echo
		eval $COMPARE_CMD --print-monitor iostat
		PARAM_LIST="avgqz await r_await w_await"
		TEST=`grep Device: /tmp/iostat-$$ | grep rsec | head -1`
		if [ "$TEST" != "" ]; then
			PARAM_LIST="avgqz await"
		fi
		if [ "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			for DEVICE in `grep ^Mean /tmp/iostat-$$ | awk '{print $2}' | awk -F - '{print $1}' | sort | uniq`; do
				echo "<table class=\"resultsGraphs\">"
				echo "<tr>"
				for PARAM in avgqusz await r_await w_await; do
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM.png
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM-smooth.png  --smooth
					eval $GRAPH_PSC --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM.ps
					eval $GRAPH_PSC --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM-smooth.ps  --smooth
					smoothover graph-$SUBREPORT-$DEVICE-$PARAM
				done
				echo "</tr>"
				echo "<tr>"
				for PARAM in avgrqsz rrqm wrqm; do
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM.png
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM-smooth.png  --smooth
					eval $GRAPH_PSC --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM.ps
					eval $GRAPH_PSC --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM-smooth.ps  --smooth
					smoothover graph-$SUBREPORT-$DEVICE-$PARAM
				done
				echo "</tr>"
				echo "<tr>"
				for PARAM in rkbs wkbs totalkbs; do
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM.png
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM-smooth.png  --smooth
					eval $GRAPH_PSC --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM.ps
					eval $GRAPH_PSC --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM-smooth.ps  --smooth
					smoothover graph-$SUBREPORT-$DEVICE-$PARAM
				done
				echo "</tr>"

				echo "</table>"
			done
		fi
	fi
	rm -f /tmp/iostat-$$

	if [ `ls kcache-slabs-$KERNEL_BASE* 2> /dev/null | wc -l` -gt 0 ]; then
		eval $COMPARE_BARE_CMD --print-monitor kcacheslabs > /tmp/kcache.$$
		ALLOCS=`grep ^Max /tmp/kcache.$$ | grep allocs | awk '{print $3}' | sed -e 's/\..*//'`
		FREES=`grep ^Max /tmp/kcache.$$ | grep frees | awk '{print $3}' | sed -e 's/\..*//'`

		echo
		echo Kcache activity
		eval $COMPARE_CMD --print-monitor kcacheslabs

		if [ "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --yrange 0:$((ALLOCS+FREES)) --title \"Kcache allocations\"   --print-monitor kcacheslabs --sub-heading allocs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-kcache-allocs.png
			eval $GRAPH_PNG --yrange 0:$((ALLOCS+FREES)) --title \"Kcache frees\"         --print-monitor kcacheslabs --sub-heading frees  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-kcache-frees.png
			eval $GRAPH_PSC --yrange 0:$((ALLOCS+FREES)) --title \"Kcache allocations\"   --print-monitor kcacheslabs --sub-heading allocs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-kcache-allocs.ps
			eval $GRAPH_PSC --yrange 0:$((ALLOCS+FREES)) --title \"Kcache frees\"         --print-monitor kcacheslabs --sub-heading frees  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-kcache-frees.ps
			echo "<table class=\"resultsGraphs\">"
			echo "<tr>"
			plain graph-$SUBREPORT-kcache-allocs
			plain graph-$SUBREPORT-kcache-frees
			echo "</tr>"
		fi
		rm /tmp/kcache.$$
	fi

	GRANULARITY=
	generate_latency_table "read-latency"
	generate_latency_table "write-latency"
	generate_latency_table "sync-latency"

	# Graphs
	if [ "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
		echo "<table class=\"resultsGraphs\">"

		case $SUBREPORT in
		aim9)
			echo "<tr>"
			for HEADING in page_test brk_test exec_test fork_test; do
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		autonumabench)
			echo "<tr>"
			for HEADING in User System Elapsed; do
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		dbench3)
			echo "<tr>"
			eval $GRAPH_PNG --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-mbsec.png
			eval $GRAPH_PSC --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-mbsec.ps
			plain graph-$SUBREPORT-mbsec
			echo "</tr>"
			;;
		dbench4|tbench4)
			echo "<tr>"
			eval $GRAPH_PNG --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-mbsec.png
			eval $GRAPH_PSC --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-mbsec.ps
			plain graph-$SUBREPORT-mbsec
			echo "</tr>"
			;;
		dbt5-bench)
			echo "<tr>"
			eval $GRAPH_PNG --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			for HEADING in System Elapsd; do
				eval $GRAPH_PNG --logX -b dbt5exectime --title \"$SUBREPORT $HEADING exec time\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime-$HEADING.png
				eval $GRAPH_PSC --logX -b dbt5exectime --title \"$SUBREPORT $HEADING exec time\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime-$HEADING.ps
			done
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-exectime-System
			plain graph-$SUBREPORT-exectime-Elapsd
			echo "</tr>"
			;;

		ebizzy)
			echo "<tr>"
			eval $GRAPH_PNG --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		dedup)
			echo "<tr>"
			eval $GRAPH_PNG --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png --y-label secs
			eval $GRAPH_PSC --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps --y-label secs
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		freqmine-small|freqmine-medium|freqmine-large)
			echo "<tr>"
			eval $GRAPH_PNG --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png --y-label secs
			eval $GRAPH_PSC --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps --y-label secs
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		futexbench-hash|futexbench-requeue|futexbench-wake)
			echo "<tr>"
			eval $GRAPH_PNG --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		filelockperf-flock|filelockperf-posix|filelockperf-lease)
			SUB_WORKLOADS_FILENAME=`find -name "workloads" | grep $SUBREPORT | head -1`
			SUB_WORKLOADS=`cat $SUB_WORKLOADS_FILENAME | sed -e 's/,/ /g'`
			for LOCKTYPE in single multi; do
				echo "<tr>"
				for SUB_WORKLOAD in $SUB_WORKLOADS; do
						eval $GRAPH_PNG --title \"$SUBREPORT $SUB_WORKLOAD $LOCKTYPE\" --sub-heading $SUB_WORKLOAD-$LOCKTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$SUB_WORKLOAD-$LOCKTYPE.png
						eval $GRAPH_PSC --title \"$SUBREPORT $SUB_WORKLOAD $LOCKTYPE\" --sub-heading $SUB_WORKLOAD-$LOCKTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$SUB_WORKLOAD-$LOCKTYPE.ps
						plain graph-$SUBREPORT-$SUB_WORKLOAD-$LOCKTYPE
				done
				echo "</tr>"
			done
			;;
		unixbench-dhry2reg|unixbench-syscall|unixbench-pipe|unixbench-spawn|unixbench-execl)
			echo "<tr>"
			eval $GRAPH_PNG --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		fsmark-threaded|fsmark-single)
			eval $GRAPH_PNG        -b $SUBREPORT --title \"$SUBREPORT files/sec\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC        -b $SUBREPORT --title \"$SUBREPORT files/sec\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			eval $GRAPH_PNG        -b ${SUBREPORT}overhead --title \"$SUBREPORT overhead\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-overhead.png
			eval $GRAPH_PSC        -b ${SUBREPORT}overhead --title \"$SUBREPORT overhead\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-overhead.ps
			echo "<tr>"
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-overhead
			echo "</tr>"
			;;
		netperf-udp|netperfmulti-udp)
			echo "<tr>"
			eval $GRAPH_PNG --logX --title \"$SUBREPORT Send Throughput\" --sub-heading send --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-send.png
			eval $GRAPH_PSC --logX --title \"$SUBREPORT Send Throughput\" --sub-heading send --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-send.ps
			eval $GRAPH_PNG --logX --title \"$SUBREPORT Recv Throughput\" --sub-heading recv --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-recv.png
			eval $GRAPH_PSC --logX --title \"$SUBREPORT Recv Throughput\" --sub-heading recv --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-recv.ps
			plain graph-$SUBREPORT-send
			plain graph-$SUBREPORT-recv
			echo "</tr>"
			;;
		netperf-tcp|netperf-udp-rr|netperf-tcp-rr|netperfmulti-tcp|netperfmulti-udp-rr|netperfmulti-tcp-rr)
			echo "<tr>"
			eval $GRAPH_PNG --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX --title \"$SUBREPORT Throughput\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		sembench-sem|sembench-nanosleep|sembench-futex)
			echo "<tr>"
			eval $GRAPH_PNG --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png --y-label ops/sec
			eval $GRAPH_PSC --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps --y-label ops/sec
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		hackbench-pipes|hackbench-sockets)
			echo "<tr>"
			eval $GRAPH_PNG --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.png --y-label latency
			eval $GRAPH_PSC --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.ps  --y-label latency
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		futexwait)
			echo "<tr>"
			eval $GRAPH_PNG --logX --wide --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png --y-label Kiter/sec
			eval $GRAPH_PSC --logX --wide --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps --y-label Kiter/sec
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		pistress)
			echo "<tr>"
			eval $GRAPH_PNG --logX --wide --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png --y-label total-inversions
			eval $GRAPH_PSC --logX --wide --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps --y-label total-inversions
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		highalloc)
			;;
		gitcheckout)
			;;
		kernbench)
			echo "<tr>"
			for HEADING in user syst elsp; do
				TITLE_HEADING=
				case $HEADING in
				user)
					TITLE_HEADING="User"
					;;
				syst)
					TITLE_HEADING="System"
					;;
				elsp)
					TITLE_HEADING="Elapsed"
					;;
				esac
				eval $GRAPH_PNG --title \"$SUBREPORT $TITLE_HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $TITLE_HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		starve)
			echo "<tr>"
			for HEADING in User System Elapsed CPU; do
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		ku_latency)
			;;
		johnripper)
			COUNT=-1
			for HEADING in `$EXTRACT_CMD -n $KERNEL | awk '{print $1}' | sed -e 's/[0-9]*-//' | sort | uniq`; do
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING

				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi
			;;
		libmicro)
			;;
		mutilate)
			;;
		micro)
			;;
		nas-mpi|nas-ser)
			echo "<tr>"
			eval $GRAPH_PNG --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.png
			eval $GRAPH_PSC --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		pagealloc)
			;;
		pft)
			echo "<tr>"
			eval $GRAPH_PNG --title \"$SUBREPORT faults/cpu\" --sub-heading faults/cpu --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-faultscpu.png
			eval $GRAPH_PSC --title \"$SUBREPORT faults/cpu\" --sub-heading faults/cpu --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-faultscpu.ps
			eval $GRAPH_PNG --title \"$SUBREPORT faults/sec\" --sub-heading faults/sec --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-faultssec.png
			eval $GRAPH_PSC --title \"$SUBREPORT faults/sec\" --sub-heading faults/sec --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-faultssec.ps
			plain graph-$SUBREPORT-faultscpu
			plain graph-$SUBREPORT-faultssec
			echo "</tr>"
			;;
		pgioperf)
			;;
		pgbench)
			echo "<tr>"
			eval $GRAPH_PNG        -b pgbenchloadtime --title \"$SUBREPORT init time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-loadtime.png
			eval $GRAPH_PSC        -b pgbenchloadtime --title \"$SUBREPORT init time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-loadtime.ps
			eval $GRAPH_PNG --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			eval $GRAPH_PNG --logX -b pgbenchexectime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime.png
			eval $GRAPH_PSC --logX -b pgbenchexectime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime.ps
			plain graph-$SUBREPORT-loadtime
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-exectime
			echo "</tr>"

			COUNT=0
			for CLIENT in `$COMPARE_BARE_CMD | grep ^Hmean | awk '{print $2}' | sort -n | uniq`; do
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				if [ "$CLIENT" = "1" ]; then
					LABEL="$SUBREPORT transactions $CLIENT client"
				else
					LABEL="$SUBREPORT transactions $CLIENT clients"
				fi
				eval $GRAPH_PNG --sub-heading $CLIENT --plottype lines --title \"$LABEL\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT}.png
				eval $GRAPH_PNG --sub-heading $CLIENT --plottype lines --title \"$LABEL\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT}-smooth.png --smooth
				eval $GRAPH_PSC --sub-heading $CLIENT --plottype lines --title \"$LABEL\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT}-smooth.ps  --smooth
				smoothover graph-${SUBREPORT}-trans-${CLIENT}
				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
				COUNT=$((COUNT+1))
			done
			;;
		postmark)
			echo "<tr>"
			eval $GRAPH_PNG --logY --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logY --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		reaim)
			COUNT=-1
			for HEADING in `$EXTRACT_CMD -n $KERNEL | awk -F - '{print $1}' | uniq`; do
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING

				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi
			;;
		redis)
			COUNT=-1
			for HEADING in `$EXTRACT_CMD -n $KERNEL | awk '{print $1}' | sed -e 's/[0-9]*-//' | sort | uniq`; do
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
				echo

				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi
			;;
		specjbb2013)
			;;
		stockfish)
			echo "<tr>"
			eval $GRAPH_PNG        -b stockfish     --title \"$SUBREPORT nodes/sec\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC        -b stockfish     --title \"$SUBREPORT nodes/sec\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			eval $GRAPH_PNG        -b stockfishtime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-time.png
			eval $GRAPH_PSC        -b stockfishtime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-time.ps
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-time
			echo "</tr>"
			;;

		siege)
			echo "<tr>"
			eval $GRAPH_PNG --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		stress-highalloc)
			echo "<tr>"
			for HEADING in latency-1 latency-2 latency-3; do
				eval $GRAPH_PNG --logY --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --logY --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		stutter)
			;;
		sysbench)
			echo "<tr>"
			eval $GRAPH_PNG        -b sysbenchloadtime --title \"$SUBREPORT init time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-loadtime.png
			eval $GRAPH_PSC        -b sysbenchloadtime --title \"$SUBREPORT init time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-loadtime.ps
			eval $GRAPH_PNG --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			eval $GRAPH_PNG --logX -b sysbenchexectime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime.png
			eval $GRAPH_PSC --logX -b sysbenchexectime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime.ps
			plain graph-$SUBREPORT-loadtime
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-exectime
			echo "</tr>"
			;;
		thpscale)
			echo "<tr>"

			for SIZE in fault-base fault-huge; do
				eval $GRAPH_PNG        -b thpscale --title \"$SUBREPORT $SIZE\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$SIZE.png --sub-heading $SIZE
				eval $GRAPH_PSC        -b thpscale --title \"$SUBREPORT $SIZE\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$SIZE.ps --sub-heading $SIZE
				plain graph-$SUBREPORT-$SIZE
			done
			echo "</tr>"
			;;
		timeexit)
			;;
		tiobench)
			echo "<tr>"
			for HEADING in SeqRead SeqWrite RandRead RandWrite ; do
				eval $GRAPH_PNG --logX --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --logX --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		vmr-stream)
			echo "<tr>"
			for HEADING in Add Copy; do
				eval $GRAPH_PNG --logX --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --logX --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			echo "<tr>"
			for HEADING in Scale Triad; do
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"

			;;
		wis-eventfd|wis-fallocate|wis-filelock|wis-futex|wis-getppid|wis-malloc|wis-mmap|wis-open|wis-pf|wis-pipe|wis-poll|wis-posixsems|wis-pread|wis-pthreadmutex|wis-pwrite|wis-read|wis-sched|wis-signal|wis-unlink)
			SUB_WORKLOADS_FILENAME=`find -name "workloads" | grep $SUBREPORT | head -1`
			SUB_WORKLOADS=`cat $SUB_WORKLOADS_FILENAME | sed -e 's/,/ /g'`
			for ADDRSPACE in processes threads; do
				echo "<tr>"
				for SUB_WORKLOAD in $SUB_WORKLOADS; do
						eval $GRAPH_PNG --title \"$SUBREPORT $SUB_WORKLOAD $ADDRSPACE\" --sub-heading $SUB_WORKLOAD-$ADDRSPACE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$SUB_WORKLOAD-$ADDRSPACE.png
						eval $GRAPH_PSC --title \"$SUBREPORT $SUB_WORKLOAD $ADDRSPACE\" --sub-heading $SUB_WORKLOAD-$ADDRSPACE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$SUB_WORKLOAD-$ADDRSPACE.ps
						plain graph-$SUBREPORT-$SUB_WORKLOAD-$ADDRSPACE
				done
				echo "</tr>"
			done
			;;
		*)
			eval $GRAPH_PNG --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.png
			eval $GRAPH_PSC --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.ps
			if [ "$USE_R" != "" ]; then
				eval $GRAPH_PNG --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-smooth.png --smooth
				eval $GRAPH_PSC --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-smooth.ps --smooth
			fi
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT.png ]; then
				if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-smooth.png ]; then
					smoothover graph-$SUBREPORT
				else
					plain graph-$SUBREPORT
				fi
			else
				echo "<tr><td>No graph representation</td></tr>"
			fi
			if [ "$PLOT_DETAILS" != "" ]; then
				eval $GRAPH_PNG --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-singletest --plottype run-sequence --separate-tests
				eval $GRAPH_PNG --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-singletest --plottype run-sequence --separate-tests --smooth
				for TEST_PLOT in $OUTPUT_DIRECTORY/graph-$SUBREPORT-singletest-*.png; do
					[[ $TEST_PLOT =~ "-smooth.png" ]] && continue
					dest=`basename $TEST_PLOT .png`
					smoothover $dest
				done
			fi
		esac
		echo "</table>"

		# Monitor graphs for this test
		echo "<table class=\"monitorGraphs\">"
		generate_latency_graph "read-latency" '"Read Latency"'
		generate_latency_graph "write-latency" '"Write Latency"'
		generate_latency_graph "inbox-open" '"Mail Read Latency"'
		generate_latency_graph "sync-latency" '"Sync Latency"'

		if [ `ls iotop-$KERNEL_BASE-* 2> /dev/null | wc -l` -gt 0 ]; then
			mkdir /tmp/iotop-mmtests-$$
			for OP in Read Write; do
				echo "<tr>"
				MAX=0
				for KERNEL in $KERNEL_LIST_ITER; do
					eval $EXTRACT_CMD -n $KERNEL --print-monitor iotop --sub-heading $OP > /tmp/iotop-mmtests-$$/$KERNEL-data
					THIS_MAX=`awk '{print $3}' /tmp/iotop-mmtests-$$/$KERNEL-data | sed -e 's/\\..*//' | sort -n | tail -1`
					THIS_MAX=$((THIS_MAX+1000-THIS_MAX%1000))
					if [ $MAX -lt $THIS_MAX ]; then
						MAX=$THIS_MAX
					fi
				done
				for KERNEL in $KERNEL_LIST_ITER; do

					# Per-thread graph
					PROCESS_LIST=
					TITLE_LIST=
					eval $EXTRACT_CMD -n $KERNEL --print-monitor iotop --sub-heading $OP > /tmp/iotop-mmtests-$$/$KERNEL-data
					for PROCESS in `awk '{print $2}' /tmp/iotop-mmtests-$$/$KERNEL-data | sort | uniq`; do
						PRETTY=`echo $PROCESS | sed -e 's/\[//g' -e 's/\]//g' -e 's/\.\///' -e 's/\//__/'`
						grep " $PROCESS " /tmp/iotop-mmtests-$$/$KERNEL-data | awk '{print $1" "$3}' > /tmp/iotop-mmtests-$$/$PRETTY
						PROCESS_LIST="$PROCESS_LIST /tmp/iotop-mmtests-$$/$PRETTY"
						if [ "$TITLE_LIST" = "" ]; then
							TITLE_LIST=$PRETTY
						else
							TITLE_LIST="$TITLE_LIST,$PRETTY"
						fi
					done
					eval plot --yrange 0:$MAX --title \"$KERNEL process $OP activity\" --plottype points --titles \"$TITLE_LIST\" --format png         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-${KERNEL}.png $PROCESS_LIST
					if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
						eval plot --yrange 0:$MAX --title \"$KERNEL process $OP activity\" --plottype points --titles \"$TITLE_LIST\" --format postscript  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-${KERNEL}.ps $PROCESS_LIST
					fi
					plain graph-$SUBREPORT-iotop-$OP-$KERNEL

					rm -rf /tmp/iotop-mmtests-$$/*
				done
				echo "</tr>"
			done

			# IO threads mean
			for OP in Read Write; do
				echo "<tr>"
				for CALC in mean stddev; do
					PLOT_LIST=
					TITLE_LIST=
					for KERNEL in $KERNEL_LIST_ITER; do
						eval $EXTRACT_CMD -n $KERNEL --print-monitor iotop --sub-heading $OP-$CALC | awk '{print $1" "$3}' > /tmp/iotop-mmtests-$$/$KERNEL-data
						if [ "$TITLE_LIST" = "" ]; then
							TITLE_LIST=$KERNEL
						else
							TITLE_LIST="$TITLE_LIST,$KERNEL"
						fi
						if [ "$PLOT_LIST" = "" ]; then
							PLOT_LIST="/tmp/iotop-mmtests-$$/$KERNEL-data"
						else
							PLOT_LIST="$PLOT_LIST /tmp/iotop-mmtests-$$/$KERNEL-data"
						fi
					done

					eval plot --logY --title \"$KERNEL thread-$CALC $OP\" --plottype points --titles \"$TITLE_LIST\" --format png         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC.png $PLOT_LIST
					eval plot --title \"$KERNEL thread-$CALC $OP\" --plottype lines --titles \"$TITLE_LIST\" --format png         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC-smooth.png --smooth bezier $PLOT_LIST 
					if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
						eval plot --logY --title \"$KERNEL thread-$CALC $OP\" --plottype points --titles \"$TITLE_LIST\" --format postscript  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC.ps $PLOT_LIST
						eval plot --title \"$KERNEL thread-$CALC $OP\" --plottype lines --titles \"$TITLE_LIST\" --format postscript  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC-smooth.ps --smooth bezier $PLOT_LIST
					fi
					smoothover graph-$SUBREPORT-iotop-$OP-$CALC
				done
				echo "</tr>"
			done

			rm -rf /tmp/iotop-mmtests-$$
		fi

		if [ `ls perf-time-stat-$KERNEL_BASE-* 2> /dev/null | wc -l` -gt 0 ]; then
			EVENTS=`$EXTRACT_CMD -n $KERNEL_BASE --print-monitor perf-time-stat --print-header | head -1`
			echo "<tr>"
			for EVENT in $EVENTS; do
				eval $GRAPH_PNG --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT.png
				eval $GRAPH_PSC --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT.ps
				eval $GRAPH_PNG --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT-smooth.png --smooth
				eval $GRAPH_PSC --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT-smooth.ps --smooth
				smoothover graph-$SUBREPORT-perf-time-stat-$EVENT
			done
			echo "</tr>"
		fi

		if [ `ls vmstat-$KERNEL_BASE-* | wc -l` -gt 0 ]; then
			eval $GRAPH_PNG --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us.png
			eval $GRAPH_PSC --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us.ps
			eval $GRAPH_PNG --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy.png
			eval $GRAPH_PSC --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy.ps
			eval $GRAPH_PNG --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-wa.png
			eval $GRAPH_PSC --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ay.ps
			eval $GRAPH_PNG --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us-smooth.png --smooth
			eval $GRAPH_PSC --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us-smooth.ps  --smooth
			eval $GRAPH_PNG --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy-smooth.png --smooth
			eval $GRAPH_PSC --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy-smooth.ps  --smooth
			eval $GRAPH_PNG --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-wa-smooth.png --smooth
			eval $GRAPH_PSC --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ay-smooth.ps  --smooth


			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-us
			smoothover graph-$SUBREPORT-vmstat-sy
			smoothover graph-$SUBREPORT-vmstat-wa
			echo "</tr>"

			eval $GRAPH_PNG --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy.png
			eval $GRAPH_PSC --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy.ps
			eval $GRAPH_PNG --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu.png
			eval $GRAPH_PSC --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu.ps
			eval $GRAPH_PNG --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy-smooth.png --smooth
			eval $GRAPH_PSC --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu-smooth.png --smooth
			eval $GRAPH_PSC --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu-smooth.ps --smooth
			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-ussy
			smoothover graph-$SUBREPORT-vmstat-totalcpu
			echo "</tr>"
		fi

		if [ `ls vmstat-$KERNEL_BASE-* | wc -l` -gt 0 ]; then
			eval $GRAPH_PNG --title \"Free Memory\"      --print-monitor vmstat --sub-heading free --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-free.png
			eval $GRAPH_PSC --title \"Free Memory\"      --print-monitor vmstat --sub-heading free --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-free.ps
			eval $GRAPH_PNG --title \"Context Switches\" --print-monitor vmstat --sub-heading cs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-cs.png
			eval $GRAPH_PSC --title \"Context Switches\" --print-monitor vmstat --sub-heading cs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-cs.ps
			eval $GRAPH_PNG --title \"Interrupts\"       --print-monitor vmstat --sub-heading in --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-in.png
			eval $GRAPH_PSC --title \"Interrupts\"       --print-monitor vmstat --sub-heading in --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-in.ps
			eval $GRAPH_PNG --title \"Context Switches\" --print-monitor vmstat --sub-heading cs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-cs-smooth.png --smooth
			eval $GRAPH_PSC --title \"Context Switches\" --print-monitor vmstat --sub-heading cs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-cs-smooth.ps  --smooth
			eval $GRAPH_PNG --title \"Interrupts\"       --print-monitor vmstat --sub-heading in --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-in-smooth.png --smooth
			eval $GRAPH_PSC --title \"Interrupts\"       --print-monitor vmstat --sub-heading in --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-in-smooth.ps  --smooth

			echo "<tr>"
			plain graph-$SUBREPORT-vmstat-free
			smoothover graph-$SUBREPORT-vmstat-cs
			smoothover graph-$SUBREPORT-vmstat-in
			echo "</tr>"
		fi
		if [ `ls proc-vmstat-$KERNEL_BASE-* | wc -l` -gt 0 ]; then
			eval $GRAPH_PNG --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp.png
			eval $GRAPH_PSC --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp.ps
			eval $GRAPH_PNG --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon.png
			eval $GRAPH_PSC --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon.ps
			eval $GRAPH_PNG --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file.png
			eval $GRAPH_PSC --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file.ps
			eval $GRAPH_PNG --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp-smooth.png --smooth
			eval $GRAPH_PSC --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp-smooth.ps  --smooth
			eval $GRAPH_PNG --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon-smooth.png                --smooth
			eval $GRAPH_PSC --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon-smooth.ps                 --smooth
			eval $GRAPH_PNG --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file-smooth.png                --smooth
			eval $GRAPH_PSC --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file-smooth.ps                 --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-thp
			smoothover graph-$SUBREPORT-proc-vmstat-anon
			smoothover graph-$SUBREPORT-proc-vmstat-file
			echo "</tr>"

                        eval $GRAPH_PNG --title \"Total Sector IO\" --print-monitor proc-vmstat --sub-heading pgpgtotal  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgptotal.png
                        eval $GRAPH_PSC --title \"Total Sector IO\" --print-monitor proc-vmstat --sub-heading pgpgtotal  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgptotal.ps
			eval $GRAPH_PNG --title \"Sector Reads\"      --print-monitor proc-vmstat --sub-heading pgpgin     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpin.png
			eval $GRAPH_PSC --title \"Sector Reads\"      --print-monitor proc-vmstat --sub-heading pgpgin     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpin.ps
			eval $GRAPH_PNG --title \"Sector Writes\"     --print-monitor proc-vmstat --sub-heading pgpgout    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpout.png
			eval $GRAPH_PSC --title \"Sector Writes\"     --print-monitor proc-vmstat --sub-heading pgpgout    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpout.ps
			eval $GRAPH_PNG --title \"Total Sector IO\" --print-monitor proc-vmstat --sub-heading pgpgtotal  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgptotal-smooth.png  --smooth
			eval $GRAPH_PSC --title \"Total Sector IO\" --print-monitor proc-vmstat --sub-heading pgpgtotal  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgptotal-smooth.ps   --smooth
			eval $GRAPH_PNG --title \"Sector Reads\"      --print-monitor proc-vmstat --sub-heading pgpgin     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpin-smooth.png  --smooth
			eval $GRAPH_PSC --title \"Sector Reads\"      --print-monitor proc-vmstat --sub-heading pgpgin     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpin-smooth.ps   --smooth
			eval $GRAPH_PNG --title \"Sector Writes\"     --print-monitor proc-vmstat --sub-heading pgpgout    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpout-smooth.png --smooth
			eval $GRAPH_PSC --title \"Sector Writes\"     --print-monitor proc-vmstat --sub-heading pgpgout    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpout-smooth.ps  --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-pgptotal
			smoothover graph-$SUBREPORT-proc-vmstat-pgpin
			smoothover graph-$SUBREPORT-proc-vmstat-pgpout
			echo "</tr>"
		fi
		if [ `ls proc-vmstat-$KERNEL_BASE-* | wc -l` -gt 0 ] && [ `awk '{print $12}' vmstat-* | max` -gt 0 ]; then
			eval $GRAPH_PNG --title \"Swap Usage\" --print-monitor vmstat --sub-heading swpd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-swpd.png
			eval $GRAPH_PSC --title \"Swap Usage\" --print-monitor vmstat --sub-heading swpd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-swpd.ps
			eval $GRAPH_PNG --title \"Swap Ins\"   --print-monitor vmstat --sub-heading si   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-si.png
			eval $GRAPH_PSC --title \"Swap Ins\"   --print-monitor vmstat --sub-heading si   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-si.ps
			eval $GRAPH_PNG --title \"Swap Ins\"   --print-monitor vmstat --sub-heading si   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-si-smooth.png --smooth
			eval $GRAPH_PSC --title \"Swap Ins\"   --print-monitor vmstat --sub-heading si   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-si-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Swap Outs\"  --print-monitor vmstat --sub-heading so   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-so.png
			eval $GRAPH_PSC --title \"Swap Outs\"  --print-monitor vmstat --sub-heading so   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-so.ps
			eval $GRAPH_PNG --title \"Swap Outs\"  --print-monitor vmstat --sub-heading so   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-so-smooth.png --smooth
			eval $GRAPH_PSC --title \"Swap Outs\"  --print-monitor vmstat --sub-heading so   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-so-smooth.ps --smooth

			echo "<tr>"
			plain graph-$SUBREPORT-vmstat-swpd
			smoothover graph-$SUBREPORT-vmstat-si
			smoothover graph-$SUBREPORT-vmstat-so
			echo "</tr>"
		fi

		KSWAPD_ACTIVITY=no
		for KERNEL in $KERNEL_LIST_ITER; do
			$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan | grep -q -v " 0"
			if [ $? -eq 0 ]; then
				KSWAPD_ACTIVITY=yes
			fi
		done
		if [ "$KSWAPD_ACTIVITY" = "yes" ]; then
			eval $GRAPH_PNG --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan.png
			eval $GRAPH_PSC --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan.ps
			eval $GRAPH_PNG --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan-smooth.png --smooth
			eval $GRAPH_PSC --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal.png
			eval $GRAPH_PSC --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal.ps
			eval $GRAPH_PNG --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal-smooth.png --smooth
			eval $GRAPH_PSC --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency.png
			eval $GRAPH_PSC --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency.ps
			eval $GRAPH_PNG --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency-smooth.png --smooth
			eval $GRAPH_PSC --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency-smooth.ps --smooth
			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-direct-scan
			smoothover graph-$SUBREPORT-proc-vmstat-direct-steal
			smoothover graph-$SUBREPORT-proc-vmstat-direct-efficiency
			echo "</tr>"


			eval $GRAPH_PNG --title \"KSwapd Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-scan.png
			eval $GRAPH_PSC --title \"KSwapd Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-scan.ps
			eval $GRAPH_PNG --title \"KSwapd Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-scan-smooth.png --smooth
			eval $GRAPH_PSC --title \"KSwapd Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-scan-smooth.ps --smooth
			eval $GRAPH_PNG --title \"KSwapd Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-steal.png
			eval $GRAPH_PSC --title \"KSwapd Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-steal.ps
			eval $GRAPH_PNG --title \"KSwapd Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-steal-smooth.png --smooth
			eval $GRAPH_PSC --title \"KSwapd Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-steal-smooth.ps --smooth
			eval $GRAPH_PNG --title \"KSwapd Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-efficiency.png
			eval $GRAPH_PSC --title \"KSwapd Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-efficiency.ps
			eval $GRAPH_PNG --title \"KSwapd Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-efficiency-smooth.png --smooth
			eval $GRAPH_PSC --title \"KSwapd Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-efficiency-smooth.ps --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-kswapd-scan
			smoothover graph-$SUBREPORT-proc-vmstat-kswapd-steal
			smoothover graph-$SUBREPORT-proc-vmstat-kswapd-efficiency
			echo "</tr>"

			eval $GRAPH_PNG --title \"KSwapd CPU Usage\"    --print-monitor top                                                 --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-top-kswapd.png
			eval $GRAPH_PSC --title \"KSwapd CPU Usage\"    --print-monitor top                                                 --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-top-kswapd.ps
			eval $GRAPH_PNG --title \"KSwapd CPU Usage\"    --print-monitor top                                                 --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-top-kswapd-smooth.png --smooth
			eval $GRAPH_PSC --title \"KSwapd CPU Usage\"    --print-monitor top                                                 --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-top-kswapd-smooth.ps --smooth
			eval $GRAPH_PNG --title \"File Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_file --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-file-writes.png
			eval $GRAPH_PSC --title \"File Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_file --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-file-writes.ps
			eval $GRAPH_PNG --title \"File Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_file --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-file-writes-smooth.png --smooth
			eval $GRAPH_PSC --title \"File Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_file --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-file-writes-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Anon Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-anon-writes.png
			eval $GRAPH_PSC --title \"Anon Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-anon-writes.ps
			eval $GRAPH_PNG --title \"Anon Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-anon-writes-smooth.png --smooth
			eval $GRAPH_PSC --title \"Anon Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-anon-writes-smooth.ps --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-top-kswapd
			smoothover graph-$SUBREPORT-proc-vmstat-reclaim-file-writes
			smoothover graph-$SUBREPORT-proc-vmstat-reclaim-anon-writes
			echo "</tr>"
		fi

		if [ `ls numa-meminfo-* 2> /dev/null | wc -l` -gt 0 ] && [ `zgrep ^Node numa-meminfo-* | awk '{print $2}' | sort | uniq | wc -l` -gt 1 ]; then
			eval $GRAPH_PNG --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance.png
			eval $GRAPH_PSC --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance.ps
			eval $GRAPH_PNG --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Pages migrated\"      --print-monitor proc-vmstat     --sub-heading pgmigrate_success     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success.png
			eval $GRAPH_PSC --title \"Pages migrated\"      --print-monitor proc-vmstat     --sub-heading pgmigrate_success     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success.ps
			eval $GRAPH_PNG --title \"Pages migrated\"      --print-monitor proc-vmstat     --sub-heading pgmigrate_success     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success-smooth.png --smooth
			eval $GRAPH_PSC --title \"Pages migrated\"      --print-monitor proc-vmstat     --sub-heading pgmigrate_success     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success-smooth.ps --smooth
			eval $GRAPH_PNG --title \"NUMA PTE Updates\"    --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates.png
			eval $GRAPH_PSC --title \"NUMA PTE Updates\"    --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates.ps
			eval $GRAPH_PNG --title \"NUMA PTE Updates\"    --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA PTE Updates\"    --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates-smooth.ps --smooth

			eval $GRAPH_PNG --title \"NUMA Convergence\"    --print-monitor Numaconvergence                                   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-convergence.png
			eval $GRAPH_PSC --title \"NUMA Convergence\"    --print-monitor Numaconvergence                                   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-convergence.ps
			eval $GRAPH_PNG --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local.png
			eval $GRAPH_PSC --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local.ps
			eval $GRAPH_PNG --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local-smooth.ps --smooth
			eval $GRAPH_PNG --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading numa_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote.png
			eval $GRAPH_PSC --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading numa_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote.ps
			eval $GRAPH_PNG --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading numa_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading numa_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote-smooth.ps --smooth


			echo "<tr>"
			smoothover graph-$SUBREPORT-numa-memory-balance
			smoothover graph-$SUBREPORT-proc-vmstat-pgmigrate_success
			smoothover graph-$SUBREPORT-proc-vmstat-numa-pte-updates
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-numa-convergence
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints-local
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints-remote
			echo "</tr>"
		fi

		if [ `ls proc-net-dev-$KERNEL_BASE-* 2> /dev/null | wc -l` -gt 0 ]; then
			INTERFACE_LIST=""
			if [ -e ip-addr-$KERNEL_BASE ]; then
				INTERFACE_LIST=`read-ip-addr.pl -u -f ip-addr-$KERNEL_BASE`
			else
				for NET_DEV in proc-net-dev-$KERNEL_BASE-*; do
					if [[ $NET_DEV == *".gz" ]]; then
						LIST=`gunzip -c $NET_DEV | awk '{ if($1 != "time:")  print $1 }' | sort -u`
					else
						LIST=`cat $NET_DEV | awk '{ if($1 != "time:")  print $1 }' | sort -u`
					fi
					INTERFACE_LIST=`printf "$LIST\n$INTERFACE_LIST" | sort -u`
				done
			fi

			for INTERFACE in $INTERFACE_LIST; do
				eval $GRAPH_PNG --title \"$INTERFACE Received Bytes\"      --print-monitor proc-net-dev --sub-heading $INTERFACE-rbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rbytes.png
				eval $GRAPH_PSC --title \"$INTERFACE Received Bytes\"      --print-monitor proc-net-dev --sub-heading $INTERFACE-rbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rbytes.ps
				eval $GRAPH_PNG --title \"$INTERFACE Received Packets\"    --print-monitor proc-net-dev --sub-heading $INTERFACE-rpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rpackets.png
				eval $GRAPH_PSC --title \"$INTERFACE Received Packets\"    --print-monitor proc-net-dev --sub-heading $INTERFACE-rpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rpackets.ps
				eval $GRAPH_PNG --title \"$INTERFACE Transmitted Bytes\"   --print-monitor proc-net-dev --sub-heading $INTERFACE-tbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tbytes.png
				eval $GRAPH_PSC --title \"$INTERFACE Transmitted Bytes\"   --print-monitor proc-net-dev --sub-heading $INTERFACE-tbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tbytes.ps
				eval $GRAPH_PNG --title \"$INTERFACE Transmitted Packets\" --print-monitor proc-net-dev --sub-heading $INTERFACE-tpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tpackets.png
				eval $GRAPH_PSC --title \"$INTERFACE Transmitted Packets\" --print-monitor proc-net-dev --sub-heading $INTERFACE-tpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tpackets.ps
				eval $GRAPH_PNG --title \"$INTERFACE Received Bytes\"      --print-monitor proc-net-dev --sub-heading $INTERFACE-rbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rbytes-smooth.png     --smooth
				eval $GRAPH_PSC --title \"$INTERFACE Received Bytes\"      --print-monitor proc-net-dev --sub-heading $INTERFACE-rbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rbytes-smooth.ps      --smooth
				eval $GRAPH_PNG --title \"$INTERFACE Received Packets\"    --print-monitor proc-net-dev --sub-heading $INTERFACE-rpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rpackets-smooth.png --smooth
				eval $GRAPH_PSC --title \"$INTERFACE Received Packets\"    --print-monitor proc-net-dev --sub-heading $INTERFACE-rpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rpackets-smooth.ps  --smooth
				eval $GRAPH_PNG --title \"$INTERFACE Transmitted Bytes\"   --print-monitor proc-net-dev --sub-heading $INTERFACE-tbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tbytes-smooth.png     --smooth
				eval $GRAPH_PSC --title \"$INTERFACE Transmitted Bytes\"   --print-monitor proc-net-dev --sub-heading $INTERFACE-tbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tbytes-smooth.ps      --smooth
				eval $GRAPH_PNG --title \"$INTERFACE Transmitted Packets\" --print-monitor proc-net-dev --sub-heading $INTERFACE-tpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tpackets-smooth.png --smooth
				eval $GRAPH_PSC --title \"$INTERFACE Transmitted Packets\" --print-monitor proc-net-dev --sub-heading $INTERFACE-tpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tpackets-smooth.ps  --smooth

				echo "<tr>"
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-rbytes
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-rpackets
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-tbytes
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-tpackets
				echo "</tr>"
			done
		fi

		echo "</table>"
		if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
			gzip -f $OUTPUT_DIRECTORY/*.ps
		fi
	fi
done
cat $SCRIPTDIR/shellpacks/common-footer-$FORMAT 2> /dev/null
