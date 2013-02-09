#!/bin/bash

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/config

KERNEL_BASE=
KERNEL_COMPARE=
KERNEL_EXCLUDE=
MONITORS_ANALYSERS="mmtests-duration read-latency mmtests-vmstat"

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
		KERNEL_COMPARE="$2"
		shift 2
		;;
	--result-dir)
		cd "$2" || die Result directory does not exist or is not directory
		shift 2
		;;
	*)
		echo Unrecognised argument: $1 1>&2
		shift
		;;
	esac
done

FORMAT_CMD=
if [ "$FORMAT" != "" ]; then
	FORMAT_CMD="--format $FORMAT"
fi
if [ "$OUTPUT_DIRECTORY" != "" -a ! -e "$OUTPUT_DIRECTORY" ]; then
	mkdir $OUTPUT_DIRECTORY
fi
if [ "$OUTPUT_DIRECTORY" != "" -a ! -d "$OUTPUT_DIRECTORY" ]; then
	echo Output directory is not a directory
	exit -1
fi

if [ `ls tests-timestamp-* 2> /dev/null | wc -l` -eq 0 ]; then
	die This does not look like a mmtests results directory
fi

# Only include kernels we have results for
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

# Build a list of kernels
if [ "$KERNEL_BASE" != "" ]; then
	KERNEL_LIST=$KERNEL_BASE
	for KERNEL in $KERNEL_COMPARE; do
		KERNEL_LIST=$KERNEL_LIST,$KERNEL
	done
else
	for KERNEL in `grep ^start tests-timestamp-* | awk -F : '{print $4" "$1}' | sort -n | awk '{print $2}' | sed -e 's/tests-timestamp-//'`; do
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
fi

smoothover() {
	IMG_SRC=$1.png
	IMG_SMOOTH=$1-smooth.png
	echo -n "  <td><img src=\"$IMG_SRC\" onmouseover=\"this.src='$IMG_SMOOTH'\" onmouseout=\"this.src='$IMG_SRC'\"></td>"
}

cat $SCRIPTDIR/shellpacks/common-header-$FORMAT 2> /dev/null
for SUBREPORT in `grep "test begin :: " tests-timestamp-$KERNEL_BASE | awk '{print $4}'`; do
	COMPARE_CMD="compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD"
	GRAPH_CMD="graph-mmtests.sh -d . -b $SUBREPORT -n $KERNEL_LIST --format png"
	echo
	case $SUBREPORT in
	dbench3)
		echo $SUBREPORT MB/sec
		eval $COMPARE_CMD --sub-heading MB/sec
		;;
	dbench4|tbench4)
		echo $SUBREPORT MB/sec
		eval $COMPARE_CMD --sub-heading MB/sec
		echo $SUBREPORT Latency
		eval $COMPARE_CMD --sub-heading Latency
		;;
	fsmark-single|fsmark-threaded)
		echo $SUBREPORT Files/sec
		eval $COMPARE_CMD --sub-heading Files/sec
		echo $SUBREPORT Latency
		eval $COMPARE_CMD --sub-heading Overhead
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
	*)
		echo $SUBREPORT
		eval $COMPARE_CMD
		;;
	esac
	echo
	eval $COMPARE_CMD --print-monitor duration
	echo
	eval $COMPARE_CMD --print-monitor mmtests-vmstat

	# Graphs
	if [ "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
		echo "<table class=\"resultsGraphs\">"

		case $SUBREPORT in
		aim9)
			;;
		dbench3)
			echo "<tr>"
			eval $GRAPH_CMD --logX --title \"$SUBREPORT $HEADING\" --sub-heading MB/sec --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-MB_sec.png
			echo "<td><img src=\"graph-$SUBREPORT-MB_sec.png\"></td>"
			echo "</tr>"
			;;
		dbench4|tbench4)
			echo "<tr>"
			for HEADING in MB/sec Latency; do
				PRINTHEADING=$HEADING
				if [ "$HEADING" = "MB/sec" ]; then
					PRINTHEADING=MB_sec
				fi
				eval $GRAPH_CMD --logX --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$PRINTHEADING.png --y-label $HEADING
				echo "<td><img src=\"graph-$SUBREPORT-$PRINTHEADING.png\"></td>"
			done
			echo "</tr>"
			;;
		ffsb)
			;;
		fsmark-single|fsmark-threaded)
			echo "<tr>"
			for HEADING in Files/sec Overhead; do
				PRINTHEADING=$HEADING
				if [ "$HEADING" = "Files/sec" ]; then
					PRINTHEADING=Files_sec
				fi
				eval $GRAPH_CMD --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$PRINTHEADING.png
				echo "<td><img src=\"graph-$SUBREPORT-$PRINTHEADING.png\"></td>"
			done
			echo "</tr>"
			;;
		kernbench|starve)
			echo "<tr>"
			for HEADING in User System Elapsed CPU; do
				eval $GRAPH_CMD --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				echo "<td><img src=\"graph-$SUBREPORT-$HEADING.png\"></td>"
			done
			echo "</tr>"
			;;
		largedd)
			;;
		micro)
			;;
		nas-mpi)
			;;
		nas-ser)
			;;
		pagealloc)
			;;
		pft)
			;;
		postmark)
			;;
		specjvm)
			;;
		stress-highalloc)
			;;
		vmr-stream)
			;;
		*)
			eval $GRAPH_CMD --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.png
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT.png ]; then
				echo "<tr><td><img src=\"graph-$SUBREPORT.png\"></td></tr>"
			else
				echo "<tr><td>No graph representation</td></tr>"
			fi
		esac
		echo "</table>"

		if [ `ls read-latency-$KERNEL_BASE-* 2> /dev/null | wc -l` -gt 0 ]; then
			echo "<table class=\"resultsGraphs\">"
			eval $COMPARE_CMD --print-monitor read-latency
			echo "</table>"
		fi

		# Monitor graphs for this test
		echo "<table class=\"monitorGraphs\">"
		if [ `ls read-latency-$KERNEL_BASE-* 2> /dev/null | wc -l` -gt 0 ]; then
			eval $GRAPH_CMD --title \"Read Latency\" --print-monitor read-latency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-read-latency.png
			eval $GRAPH_CMD --title \"Read Latency\" --print-monitor read-latency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-read-latency-smooth.png --smooth
			smoothover graph-$SUBREPORT-read-latency
		fi
		if [ `ls vmstat-$KERNEL_BASE-* | wc -l` -gt 0 ]; then
			eval $GRAPH_CMD --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us.png
			eval $GRAPH_CMD --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy.png
			eval $GRAPH_CMD --title \"Context Switches\" --print-monitor vmstat --sub-heading cs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-cs.png
			eval $GRAPH_CMD --title \"Context Switches\" --print-monitor vmstat --sub-heading cs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-cs-smooth.png --smooth
			eval $GRAPH_CMD --title \"Interrupts\"       --print-monitor vmstat --sub-heading in --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-in.png
			eval $GRAPH_CMD --title \"Interrupts\"       --print-monitor vmstat --sub-heading in --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-in-smooth.png --smooth
			echo "<tr>"
			echo "  <td><img src=\"graph-$SUBREPORT-vmstat-us.png\"></td>"
			echo "  <td><img src=\"graph-$SUBREPORT-vmstat-sy.png\"></td>"
			smoothover graph-$SUBREPORT-vmstat-cs
			smoothover graph-$SUBREPORT-vmstat-in
			echo "</tr>"
		fi
		if [ `ls top-* 2> /dev/null | wc -l` -gt 0 ] && [ `zgrep kswapd top-* | awk '{print $10}' | max | cut -d. -f1` -gt 0 ]; then
			eval $GRAPH_CMD --title \"Free Memory\"      --print-monitor vmstat --sub-heading free --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-free.png
			eval $GRAPH_CMD --title \"Swap Ins\"         --print-monitor vmstat --sub-heading si --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-si.png
			eval $GRAPH_CMD --title \"Swap Outs\"        --print-monitor vmstat --sub-heading so --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-so.png
			eval $GRAPH_CMD --title \"KSwapd CPU Usage\" --print-monitor top                     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-top-kswapd.png
			eval $GRAPH_CMD --title \"KSwapd CPU Usage\" --print-monitor top                     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-top-kswapd-smooth.png --smooth
			echo "<tr>"
			echo "  <td><img src=\"graph-$SUBREPORT-vmstat-free.png\"></td>"
			echo "  <td><img src=\"graph-$SUBREPORT-vmstat-si.png\"></td>"
			echo "  <td><img src=\"graph-$SUBREPORT-vmstat-so.png\"></td>"
			smoothover graph-$SUBREPORT-top-kswapd
			echo "</tr>"

			eval $GRAPH_CMD --title \"Direct Reclaim Scan\" --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan.png
			eval $GRAPH_CMD --title \"Direct Reclaim Scan\" --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan-smooth.png --smooth
			eval $GRAPH_CMD --title \"Page Ins\"            --print-monitor proc-vmstat --sub-heading pgpgin  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpin.png
			eval $GRAPH_CMD --title \"Page Ins\"            --print-monitor proc-vmstat --sub-heading pgpgin  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpin-smooth.png --smooth
			eval $GRAPH_CMD --title \"Page Outs\"           --print-monitor proc-vmstat --sub-heading pgpgout --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpout.png
			eval $GRAPH_CMD --title \"Page Outs\"           --print-monitor proc-vmstat --sub-heading pgpgout --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpout-smooth.png --smooth
			eval $GRAPH_CMD --title \"KSwapd Reclaim Scan\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-scan.png
			eval $GRAPH_CMD --title \"KSwapd Reclaim Scan\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-scan-smooth.png --smooth
			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-direct-scan
			smoothover graph-$SUBREPORT-proc-vmstat-pgpin
			smoothover graph-$SUBREPORT-proc-vmstat-pgpout
			smoothover graph-$SUBREPORT-proc-vmstat-kswapd-scan
			echo "</tr>"
		fi

		echo "</table>"
	fi
done
cat $SCRIPTDIR/shellpacks/common-footer-$FORMAT 2> /dev/null
