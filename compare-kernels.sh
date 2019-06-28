#!/bin/bash

export SCRIPT=$(basename $0)
export SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/config
export PATH=$SCRIPTDIR/bin:$PATH

KERNEL_BASE=
KERNEL_COMPARE=
POSTSCRIPT_OUTPUT=no

while [ "$1" != "" ]; do
	case $1 in
	--auto-detect)
		AUTO_DETECT_SIGNIFICANCE="--print-significance"
		shift
		;;
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
	--exclude)
		KERNEL_EXCLUDE=$2
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
	--plot-details)
		PLOT_DETAILS="yes"
		shift
		;;
	--exclude-monitors)
		EXCLUDE_MONITORS=yes
		shift
		;;
	--help) cat <<EOF
${SCRIPT} [OPTIONS]

Compare mmtests benchmark results for different kernels.
In principle its a wrapper to invoke compare-mmtests.pl.

Options:

  --auto-detect		add significance in comparison
  --format	<fmt>	format of comparison (html or text)
  --output-dir	<dir>	output directory (e.g. for html format and graphs)
  --baseline	<vers>	specify kernel version as baseline for comparison
  --compare	<vers>	include kernel version in comparison
  --exclude	<vers>	exclude kernel version from comparison
  --result-dir	<dir>	directory with mmtests results
  --sort-version	sort results by kernel version
  --plot-details	generate graphs for comparison
  --exclude-monitors	don't include monitors in comparison
  --help		print this help text and exit

EOF
		shift; exit 0;;
	*)
		echo Unrecognised argument: $1 1>&2
		shift
		;;
	esac
done

if [ "$CACHE_MMTESTS" != "" ]; then
	mkdir -p $CACHE_MMTESTS
	if [ -e $CACHE_MMTESTS/current_update ]; then
		CLEANUP_PID=`cat $CACHE_MMTESTS/current_update 2> /dev/null`
		if [ "$CLEANUP_PID" != "" ]; then
			ps -p $CLEANUP_PID > /dev/null
			if [ $? -ne 0 ]; then
				rm $CACHE_MMTESTS/current_update 2> /dev/null
			fi
		fi
	else
		echo $$ > $CACHE_MMTESTS/current_update
		CURRENT_UPDATE=`date +%s`
		CURRENT_UPDATE=$((CURRENT_UPDATE/86400))
		LAST_UPDATE=`cat $CACHE_MMTESTS/last_update 2> /dev/null`
		if [ "$LAST_UPDATE" != "$CURRENT_UPDATE" ]; then
			find $CACHE_MMTESTS -maxdepth 3 -type f -atime +14 -exec rm -rf {} \;
		fi
		echo -n $CURRENT_UPDATE > $CACHE_MMTESTS/last_update
		rm $CACHE_MMTESTS/current_update
	fi
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

if ! have_run_results; then
	die This does not look like a mmtests results directory
fi

if [ -n "$KERNEL_BASE" ]; then
	for KERNEL in $KERNEL_COMPARE $KERNEL_BASE; do
		if ! have_run_results $KERNEL; then
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
	for KERNEL in $(run_results); do
		if [ "$KERNEL_BASE" = "" ]; then
			KERNEL_BASE=$KERNEL
			KERNEL_LIST=$KERNEL
		else
			KERNEL_LIST="$KERNEL_LIST,$KERNEL"
		fi
	done
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

logyover() {
	IMG_SRC=$1
	IMG_LOGY=$1-logY
	if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
		echo -n "  <td><a href=\"$IMG_LOGY.ps.gz\"><img src=\"$IMG_LOGY.png\" onmouseover=\"this.src='$IMG_SRC.png'\" onmouseout=\"this.src='$IMG_LOGY.png'\"></a></td>"
	else
		echo -n "  <td><img src=\"$IMG_LOGY.png\" onmouseover=\"this.src='$IMG_SRC.png'\" onmouseout=\"this.src='$IMG_LOGY.png'\"></td>"
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

generate_latency_graph() {
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

generate_client_trans_graphs() {
	CLIENT_LIST=$1
	XLABEL="$2"
	if [ "$CLIENT_LIST" = "" ]; then
		CLIENT_LIST=`$COMPARE_BARE_CMD | grep ^Hmean | awk '{print $2}' | sort -n | uniq`
		if [ "$CLIENT_LIST" = "" ]; then
			CLIENT_LIST=`$COMPARE_BARE_CMD | grep ^Amean | awk '{print $2}' | sort -n | uniq`
		fi
	fi
	if [ "$XLABEL" = "" ]; then
		XLABEL="Time"
	fi
	COUNT=0
	for CLIENT in $CLIENT_LIST; do
		CLIENT_FILENAME=`echo $CLIENT | sed -e 's/\///'`
		echo "<tr>"
		if [ "$CLIENT" = "1" ]; then
			LABEL="$SUBREPORT transactions $CLIENT client"
		else
			LABEL="$SUBREPORT transactions $CLIENT clients"
		fi
		eval $GRAPH_PNG --sub-heading $CLIENT --plottype lines --title \"$LABEL\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT_FILENAME}.png --x-label \"$XLABEL\"
		eval $GRAPH_PNG --sub-heading $CLIENT --plottype lines --title \"$LABEL smooth\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT_FILENAME}-smooth.png --smooth --x-label \"$XLABEL\"
		eval $GRAPH_PNG --sub-heading $CLIENT --plottype lines --title \"$LABEL sorted\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT_FILENAME}-sorted.png --sort-samples-reverse --x-label \"Sorted samples\"
		plain graph-${SUBREPORT}-trans-${CLIENT_FILENAME}
		plain graph-${SUBREPORT}-trans-${CLIENT_FILENAME}-smooth
		plain graph-${SUBREPORT}-trans-${CLIENT_FILENAME}-sorted
		echo "</tr>"
		COUNT=$((COUNT+1))
	done
}

generate_ops_graphs() {
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
}

generate_client_subtest_graphs() {
	COUNT=-1
	WRAP=$1
	if [ "$WRAP" = "" ]; then
		WRAP=3
	fi
	for HEADING in `$EXTRACT_CMD -n $KERNEL | awk -F - '{print $1}' | sort | uniq`; do
		COUNT=$((COUNT+1))
		if [ $((COUNT%$WRAP)) -eq 0 ]; then
			echo "<tr>"
		fi
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
		eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
		plain graph-$SUBREPORT-$HEADING
		if [ $((COUNT%$WRAP)) -eq $((WRAP-1)) ]; then
			echo "</tr>"
		fi
	done
	if [ $((COUNT%$WRAP)) -ne $((WRAP-1)) ]; then
		echo "</tr>"
	fi
}

SAVE_CACHE_MMTESTS=

save_cache_mmtests() {
	SAVE_CACHE_MMTESTS=$CACHE_MMTESTS
	unset CACHE_MMTESTS
}

restore_cache_mmtests() {
	export CACHE_MMTESTS=$SAVE_CACHE_MMTESTS
	unset SAVE_CACHE_MMTESTS
}

generate_subtest_graphs() {
	COUNT=-1
	WRAP=$1
	if [ "$WRAP" = "" ]; then
		WRAP=3
	fi
	SUBTEST_LIST=$2
	if [ "$SUBTEST_LIST" = "" ]; then
		SUBTEST_LIST=`eval $EXTRACT_CMD -n $KERNEL | awk '{print $1}' | sort | uniq | sed -e 's/ /@/g'`
	fi
	save_cache_mmtests
	for HEADING in $SUBTEST_LIST; do
		HEADING=`echo $HEADING | sed -e 's/@/ /g'`
		HEADING_FILENAME=`echo $HEADING | sed -e 's/ //g'`
		COUNT=$((COUNT+1))
		if [ $((COUNT%$WRAP)) -eq 0 ]; then
			echo "<tr>"
		fi
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME.png
		eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME.ps
		plain graph-$SUBREPORT-$HEADING_FILENAME
		if [ $((COUNT%$WRAP)) -eq $((WRAP-1)) ]; then
			echo "</tr>"
		fi
	done
	if [ $((COUNT%$WRAP)) -ne $((WRAP-1)) ]; then
		echo "</tr>"
	fi
	restore_cache_mmtests
}

generate_subtest_graphs_sorted() {
	SUBTEST_LIST=$1
	if [ "$SUBTEST_LIST" = "" ]; then
		SUBTEST_LIST=`eval $EXTRACT_CMD -n $KERNEL | awk '{print $1}' | sort | uniq | sed -e 's/ /@/g'`
	fi
	save_cache_mmtests
	for HEADING in $SUBTEST_LIST; do
		HEADING=`echo $HEADING | sed -e 's/@/ /g'`
		HEADING_FILENAME=`echo $HEADING | sed -e 's/ //g'`
		echo "<tr>"
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME.png
		eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME.ps
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING sorted\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME-sorted.png --sort-samples --sort-percentages 5
		eval $GRAPH_PSC --title \"$SUBREPORT $HEADING sorted\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME-sorted.ps  --sort-samples --sort-percentages 5
		if [ "$2" != "--logY" ]; then
			plain graph-$SUBREPORT-$HEADING_FILENAME
			plain graph-$SUBREPORT-$HEADING_FILENAME-sorted
		else
			eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME-logY.png --logY
			eval $GRAPH_PNG --title \"$SUBREPORT $HEADING sorted\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME-sorted-logY.png --sort-samples --sort-percentages 5 --logY

			logyover graph-$SUBREPORT-$HEADING_FILENAME
			logyover graph-$SUBREPORT-$HEADING_FILENAME-sorted
		fi
		echo "</tr>"
	done
	restore_cache_mmtests
}

generate_cputime_graphs() {
	echo "<tr>"
	for HEADING in User System Elapsed; do
		$EXTRACT_CMD --print-plot --sub-heading $HEADING -n $KERNEL_BASE | grep -q NaN
		if [ $? -ne 0 ]; then
			eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
			eval $GRAPH_PSC --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
			plain graph-$SUBREPORT-$HEADING
		else
			echo "<td><center>No $HEADING CPU activity</center></td>"
		fi
	done
	echo "</tr>"
}

generate_basic_single() {
	TITLE="$1"
	EXTRA="$2"

	if [ "$TITLE" = "" ]; then
		TITLE="SUBREPORT"
	fi
	if [ "$EXTRA" != "" ]; then
		EXTRA_FILENAME=`echo $EXTRA | sed -e 's/--/-/g' | sed -e 's/ /-/g'`
		EXTRA_TITLE=`echo " $EXTRA" | sed -e 's/--wide//' -e 's/--//g'`
	fi

	eval $GRAPH_PNG $EXTRA --title \"$TITLE$EXTRA_TITLE\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT$EXTRA_FILENAME.png
	eval $GRAPH_PSC $EXTRA --title \"$TITLE$EXTRA_TITLE\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT$EXTRA_FILENAME.ps
	plain graph-$SUBREPORT$EXTRA_FILENAME
}

generate_basic() {
	echo "<tr>"
	generate_basic_single "$1" "$2"
	echo "</tr>"
}

generate_subheading_graphs() {
	SUBHEADING_LIST=$1
	WRAP=$2
	SUBTEST=$3
	EXTRA=$4
	if [ "$SUBTEST" = "" ]; then
		SUBTEST=$SUBREPORT
	fi
	if [ "$WRAP" = "" ]; then
		WRAP=3
	fi

	COUNT=-1
	for SUBHEADING in $SUBHEADING_LIST; do
		COUNT=$((COUNT+1))
		if [ $((COUNT%$WRAP)) -eq 0 ]; then
			echo "<tr>"
		fi
		eval $GRAPH_PNG -b $SUBTEST --title \"$SUBTEST $SUBHEADING\" $EXTRA --sub-heading $SUBHEADING  --output $OUTPUT_DIRECTORY/graph-$SUBTEST-$SUBHEADING.png
		plain graph-$SUBTEST-$SUBHEADING
		if [ $((COUNT%$WRAP)) -eq $((WRAP-1)) ]; then
			echo "</tr>"
		fi
	done
	if [ $((COUNT%$WRAP)) -ne $((WRAP-1)) ]; then
		echo "</tr>"
	fi
}

generate_subheading_trans_graphs() {
	SUBHEADING_LIST=$1
	SUBTEST=$2
	EXTRA=$3
	if [ "$SUBTEST" = "" ]; then
		SUBTEST=$SUBREPORT
	fi

	for SUBHEADING in $SUBHEADING_LIST; do
		echo "<tr>"
		eval $GRAPH_PNG -a $SUBTEST --title \"$SUBTEST $SUBHEADING\" $EXTRA --sub-heading $SUBHEADING  --output $OUTPUT_DIRECTORY/graph-$SUBTEST-$SUBHEADING.png --x-label Time
		eval $GRAPH_PNG -a $SUBTEST --title \"$SUBTEST $SUBHEADING smooth\" $EXTRA --sub-heading $SUBHEADING  --output $OUTPUT_DIRECTORY/graph-$SUBTEST-$SUBHEADING-smooth.png --smooth --x-label Time
		eval $GRAPH_PNG -a $SUBTEST --title \"$SUBTEST $SUBHEADING sorted\" $EXTRA --sub-heading $SUBHEADING  --output $OUTPUT_DIRECTORY/graph-$SUBTEST-$SUBHEADING-sorted.png --sort-samples-reverse --x-label \"Sorted samples\"
		plain graph-$SUBTEST-$SUBHEADING
		plain graph-$SUBTEST-$SUBHEADING-smooth
		plain graph-$SUBTEST-$SUBHEADING-sorted
		echo "</tr>"
	done
}

cat $SCRIPTDIR/shellpacks/common-header-$FORMAT 2> /dev/null
for SUBREPORT in $(run_report_name $KERNEL_BASE); do
	EXTRACT_CMD="cache-mmtests.sh extract-mmtests.pl -d . -b $SUBREPORT"
	COMPARE_CMD="cache-mmtests.sh compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD $AUTO_DETECT_SIGNIFICANCE"
	COMPARE_BARE_CMD="cache-mmtests.sh compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST"
	GRAPH_PNG="graph-mmtests.sh -d . -b $SUBREPORT -n $KERNEL_LIST --format png"
	if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
		GRAPH_PSC="graph-mmtests.sh -d . -b $SUBREPORT -n $KERNEL_LIST --format \"postscript color solid\""
	else
		GRAPH_PSC="#"
	fi
	echo
	if [ "$FORMAT" = "html" ]; then
		echo "<a name="$SUBREPORT">"
	fi
	case $SUBREPORT in
	dbench4)
		echo $SUBREPORT Loadfile Execution Time
		$COMPARE_CMD
		echo
		echo $SUBREPORT Latency
		cache-mmtests.sh compare-mmtests.pl -d . -b dbench4 -a latency -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo "$SUBREPORT Throughput (misleading but traditional)"
		cache-mmtests.sh compare-mmtests.pl -d . -b dbench4 -a tput -n $KERNEL_LIST $FORMAT_CMD
		echo

		echo $SUBREPORT Per-VFS Operation latency Latency
		cache-mmtests.sh compare-mmtests.pl -d . -b dbench4 -a opslatency -n $KERNEL_LIST $FORMAT_CMD
		;;
	bonnie)
		echo "$SUBREPORT IO Execution Time"
		$COMPARE_CMD
		echo
		echo "$SUBREPORT Throughput"
		cache-mmtests.sh compare-mmtests.pl -d . -b bonnie -a tput -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	ebizzy)
		echo $SUBREPORT Overall Throughput
		$COMPARE_CMD
		echo
		echo $SUBREPORT Per-thread
		cache-mmtests.sh compare-mmtests.pl -d . -b ebizzy -a thread -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Thread spread
		cache-mmtests.sh compare-mmtests.pl -d . -b ebizzy -a range -n $KERNEL_LIST $FORMAT_CMD
		;;
	fio)
		echo $SUBREPORT Throughput
		$COMPARE_CMD
		echo
		echo $SUBREPORT Latency read
		cache-mmtests.sh compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b fio -a latency -n $KERNEL_LIST --sub-heading latency-read $FORMAT_CMD

		echo
		echo $SUBREPORT Latency write
		cache-mmtests.sh compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b fio -a latency -n $KERNEL_LIST --sub-heading latency-write $FORMAT_CMD
		echo
		# all sub-headings (ie. fio-scaling-[rand]{rw,read,write}-{read,write})
		echo $SUBREPORT scaling
		cache-mmtests.sh compare-mmtests.pl -d . -b fio -a scaling -n $KERNEL_LIST 2> /dev/null
		# all sub-headings (ie. fio-ssd-{rand|seq}_jobs_{1|4}-qd_{1|32}-bs_{4k|128k}-{read|write})
		echo $SUBREPORT ssd
		cache-mmtests.sh compare-mmtests.pl -d . -b fio -a ssd -n $KERNEL_LIST 2> /dev/null
		;;
	fsmark-single|fsmark-threaded)
		echo $SUBREPORT
		$COMPARE_CMD
		echo
		echo $SUBREPORT App Overhead
		cache-mmtests.sh compare-mmtests.pl -d . -b ${SUBREPORT}overhead -n $KERNEL_LIST $FORMAT_CMD
		;;
	johnripper)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo

		echo $SUBREPORT User/System CPU time
		cache-mmtests.sh compare-mmtests.pl -d . -b johnripper -a exectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	monitor)
		echo No meaningful extraction script for monitor
		echo
		;;
	nas*)
		echo $SUBREPORT NAS Time
		cache-mmtests.sh compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Wall Time
		cache-mmtests.sh compare-mmtests.pl -d . -b ${SUBREPORT} -a time -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	netpipe)
		echo $SUBREPORT Throughput
		cache-mmtests.sh compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b netpipe -a 4mb -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	parallelio)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Background IO
		cache-mmtests.sh compare-mmtests.pl -d . -b parallelio -a io -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Swap totals
		cache-mmtests.sh compare-mmtests.pl -d . -b parallelio -a swap -n $KERNEL_LIST $FORMAT_CMD
		;;
	parsecbuild)
		echo $SUBREPORT
		;;
	pft)
		echo $SUBREPORT timings
		cache-mmtests.sh compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b pft -a time -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT faults
		eval $COMPARE_CMD
		;;
	pgbench)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		cache-mmtests.sh compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b pgbench -a stalls -n $KERNEL_LIST $FORMAT_CMD > /tmp/pgbench-$$
		TEST=`grep MinStall-1 /tmp/pgbench-$$ | grep -v nan`
		if [ "$TEST" != "" ]; then
			echo
			echo $SUBREPORT Stalls
			cat /tmp/pgbench-$$
		fi
		rm /tmp/pgbench-$$
		echo
		echo $SUBREPORT Time
		cache-mmtests.sh compare-mmtests.pl -d . -b pgbench -a exectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	simoop)
		echo $SUBREPORT latencies
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT rates
		cache-mmtests.sh compare-mmtests.pl -d . -b simoop -a rates -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	specjvm)
		echo $SUBREPORT
		eval $COMPARE_CMD
		;;
	specjbb)
		echo $SUBREPORT
		eval $COMPARE_CMD
		;;
	speccpu2017-*-build)
		echo $SUBREPORT
		;;
	stockfish)
		echo $SUBREPORT Nodes/sec
		cache-mmtests.sh compare-mmtests.pl -d . -b stockfish -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Execution time
		cache-mmtests.sh compare-mmtests.pl -d . -b stockfish -a time -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	stutter)
		echo $SUBREPORT
		$COMPARE_CMD
		echo
		echo $SUBREPORT estimated write speed
		cache-mmtests.sh compare-mmtests.pl -d . -b stutter -a calibrate -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT parallel write throughput
		cache-mmtests.sh compare-mmtests.pl -d . -b stutter -a throughput -n $KERNEL_LIST $FORMAT_CMD
		;;
	sysbench)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Time
		cache-mmtests.sh compare-mmtests.pl -d . -b sysbench -a exectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	thp*scale)
		echo $SUBREPORT Fault Latencies
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Percentage Faults Huge
		cache-mmtests.sh compare-mmtests.pl -d . -b $SUBREPORT -a counts -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	xfsio)
		echo $SUBREPORT Time
		$COMPARE_CMD
		echo
		echo $SUBREPORT Throughput
		cache-mmtests.sh compare-mmtests.pl -d . -b xfsio -a throughput -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Ops
		cache-mmtests.sh compare-mmtests.pl -d . -b xfsio -a ops -n $KERNEL_LIST $FORMAT_CMD
		;;
	*)
		echo $SUBREPORT
		eval $COMPARE_CMD
	esac
	echo
	eval $COMPARE_CMD --print-monitor duration
	echo

	if [ "$EXCLUDE_MONITORS" = "yes" ]; then
		continue
	fi
	eval $COMPARE_CMD --print-monitor mmtests-vmstat

	if have_monitor_results turbostat $KERNEL_BASE; then
		eval $COMPARE_CMD --print-monitor turbostat
	fi

	if have_monitor_results perf-time-stat $KERNEL_BASE; then
		eval $COMPARE_CMD --print-monitor perf-time-stat
	fi

	IOSTAT_GRAPH=no
	TEST=
	if have_monitor_results iostat $KERNEL_BASE; then
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
		IOSTAT_GRAPH=yes

		if [ "$FORMAT" != "html" ]; then
			rm /tmp/iostat-$$
		fi
	fi

	KCACHE_GRAPH=no
	if have_monitor_results kcache-slabs $KERNEL_BASE; then
		eval $COMPARE_BARE_CMD --print-monitor kcacheslabs > /tmp/kcache.$$
		ALLOCS=`grep ^Max /tmp/kcache.$$ | grep allocs | awk '{print $3}' | sed -e 's/\..*//'`
		FREES=`grep ^Max /tmp/kcache.$$ | grep frees | awk '{print $3}' | sed -e 's/\..*//'`

		echo
		echo Kcache activity
		eval $COMPARE_CMD --print-monitor kcacheslabs
		KCACHE_ACTIVITY=yes
	fi

	FTRACE_ALLOCLATENCY_GRAPH=no
	if have_monitor_results ftrace $KERNEL_BASE mm_vmscan_direct_reclaim_begin; then
		echo Ftrace direct reclaim allocation stalls
		eval $COMPARE_CMD --print-monitor ftraceallocstall
		echo
		FTRACE_ALLOCLATENCY_GRAPH=yes
	fi

	FTRACE_SHRINKERLATENCY_GRAPH=no
	if have_monitor_results ftrace $KERNEL_BASE mm_shrink_slab_start; then
		echo Ftrace slab shrinker stalls kswapd
		eval $COMPARE_CMD --print-monitor ftraceshrinkerstall --sub-heading kswapd
		echo Ftrace slab shrinker stalls not kswapd
		eval $COMPARE_CMD --print-monitor ftraceshrinkerstall --sub-heading no-kswapd
		echo

		FTRACE_SHRINKERLATENCY_GRAPH=yes
	fi

	FTRACE_COMPACTLATENCY_GRAPH=no
	if have_monitor_results ftrace $KERNEL_BASE mm_compaction_begin; then
		echo Ftrace compaction stalls khugepaged
		eval $COMPARE_CMD --print-monitor ftracecompactstall --sub-heading khugepaged
		echo Ftrace compaction stalls kswapd or kcompactd
		eval $COMPARE_CMD --print-monitor ftracecompactstall --sub-heading kswapd-kcompactd
		echo Ftrace compaction stalls not kswapd, kcompactd or khugepaged
		eval $COMPARE_CMD --print-monitor ftracecompactstall --sub-heading no-kswapd-kcompactd-khugepaged
		echo

		FTRACE_COMPACTLATENCY_GRAPH=yes
	fi

	FTRACE_WAITIFFCONGESTED_GRAPH=no
	if have_monitor_results ftrace $KERNEL_BASE wait_iff_congested; then
		echo Ftrace wait_iff_congested kswapd
		eval $COMPARE_CMD --print-monitor ftracewaitiffcongestedstall --sub-heading kswapd
		echo Ftrace wait_iff_congested not kswapd
		eval $COMPARE_CMD --print-monitor ftracewaitiffcongestedstall --sub-heading no-kswapd
		echo

		FTRACE_WAITIFFCONGESTED_GRAPH=yes
	fi

	FTRACE_CONGESTIONWAIT_GRAPH=no
	if have_monitor_results ftrace $KERNEL_BASE "congestion_wait.*usec_delayed=[1-9]"; then
		echo Ftrace congestion_wait kswapd
		eval $COMPARE_CMD --print-monitor ftracecongestionwaitstall --sub-heading kswapd
		echo Ftrace congestion_wait not kswapd
		eval $COMPARE_CMD --print-monitor ftracecongestionwaitstall --sub-heading no-kswapd
		echo

		FTRACE_CONGESTIONWAIT_GRAPH=yes
	fi

	FTRACE_BALANCEDIRTYPAGES_GRAPH=no
	if have_monitor_results ftrace $KERNEL_BASE balance_dirty_pages; then
		echo Ftrace balance_dirty_pages
		eval $COMPARE_CMD --print-monitor ftracebalancedirtypagesstall --sub-heading no-kswapd
		echo

		FTRACE_BALANCEDIRTYPAGES_GRAPH=yes
	fi

	SWAP_GRAPH=no
	if have_monitor_results vmstat $KERNEL_BASE; then
		for EVENT in si so; do
			eval $EXTRACT_CMD --print-monitor vmstat --sub-heading si | grep -v 0.00 &> /dev/null
			if [ $? -eq 0 ]; then
				SWAP_GRAPH=yes
			fi
		done
	fi

	GRANULARITY=
	generate_latency_table "read-latency"
	generate_latency_table "write-latency"
	generate_latency_table "sync-latency"

	# Graphs
	if [ "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
		echo "<table class=\"resultsGraphs\">"

		case $SUBREPORT in
		adrestia-wakeup-*)
			;;
		aim9)
			generate_subtest_graphs 2
			;;
		bonnie)
			SUBTEST_LIST=`$EXTRACT_CMD -n $KERNEL | awk '{print $1" "$2}' | sort | uniq | sed -e 's/ /@/g'`
			generate_subtest_graphs_sorted "$SUBTEST_LIST" --logY
			;;
		autonumabench)
			generate_cputime_graphs
			;;
		blogbench)
			generate_subheading_graphs "Read Write"
			;;
		cyclictest-*)
			for HEADING in Max Avg; do
				eval $GRAPH_PNG --title \"$SUBREPORT Latency $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --title \"$SUBREPORT Latency $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			;;
		dbench4)
			echo "<tr>"
			generate_basic_single "$SUBREPORT Completion times" "--logX"
			generate_basic_single "$SUBREPORT Completion times" "--logX --logY"
			generate_client_trans_graphs "`$COMPARE_BARE_CMD | grep ^Min | awk '{print $2}' | sort -n | uniq`" "Estimated time"
			echo "</tr>"
			;;
		dedup)
			generate_basic "$SUBREPORT" "--wide --logX"
			;;
		ebizzy)
			generate_basic "$SUBREPORT" "--logX"
			;;
		filelockperf-flock|filelockperf-posix|filelockperf-lease)
			SUB_WORKLOADS_FILENAME=`find -name "workloads" | grep $SUBREPORT | head -1`
			SUB_WORKLOADS=
			if [ "$SUB_WORKLOADS_FILENAME" != "" ]; then
				SUB_WORKLOADS=`cat $SUB_WORKLOADS_FILENAME | sed -e 's/,/ /g'`
			fi
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
		fio)
			generate_subheading_trans_graphs "latency-read latency-write" "latency" "--logY"
			;;
		freqmine-small|freqmine-medium|freqmine-large)
			generate_basic "$SUBREPORT" "--wide --logX"
			;;
		fsmark-threaded|fsmark-single)
			generate_client_trans_graphs "`$COMPARE_BARE_CMD | grep ^Min | awk '{print $2}' | sort -n | uniq`"
			;;
		futexbench-hash|futexbench-requeue|futexbench-wake)
			generate_basic "$SUBREPORT" "--wide --logX"
			;;
		futexwait)
			generate_basic "$SUBREPORT" "--wide --logX"
			;;
		ipcscale-waitforzero|ipcscale-sysvsempp|ipcscale-posixsempp)
			generate_ops_graphs
			;;
		gitcheckout)
			generate_cputime_graphs
			;;
		hackbench-process-pipes|hackbench-process-sockets|hackbench-thread-pipes|hackbench-thread-sockets)
			generate_basic "$SUBREPORT" "--logX"
			;;
		highalloc)
			;;
		johnripper)
			generate_ops_graphs
			;;
		kernbench)
			echo "<tr>"
			for HEADING in elsp syst user; do
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
				eval $GRAPH_PNG --logX --title \"$SUBREPORT $TITLE_HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.png
				eval $GRAPH_PSC --logX --title \"$SUBREPORT $TITLE_HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		libmicro)
			;;
		micro)
			;;
		mlc)
			;;
		monitor)
			;;
		netpipe)
			echo "<tr>"
			generate_basic_single "$SUBREPORT Throughput"
			generate_basic_single "$SUBREPORT Throughput" "--logX"
			echo "</tr>"
			;;
		netperf-udp)
			echo "<tr>"
			eval $GRAPH_PNG --xrange 16:32768 --logX --title \"$SUBREPORT Send Throughput\" --sub-heading send --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-send.png
			eval $GRAPH_PSC --xrange 16:32768 --logX --title \"$SUBREPORT Send Throughput\" --sub-heading send --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-send.ps
			eval $GRAPH_PNG --xrange 16:32768 --logX --title \"$SUBREPORT Recv Throughput\" --sub-heading recv --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-recv.png
			eval $GRAPH_PSC --xrange 16:32768 --logX --title \"$SUBREPORT Recv Throughput\" --sub-heading recv --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-recv.ps
			plain graph-$SUBREPORT-send
			plain graph-$SUBREPORT-recv
			echo "</tr>"
			;;
		netperf-tcp|netperf-udp-rr|netperf-tcp-rr)
			generate_basic "$SUBREPORT" "--logX --xrange 16:32768"
			;;
		pagealloc)
			;;
		parsec-*)
			;;
		parsecbuild)
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
		pgioperfbench)
			for OPER in commit read wal; do
				echo "<tr>"
				eval $GRAPH_PNG --title \"$SUBREPORT $OPER\" --sub-heading $OPER --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$OPER.png
				eval $GRAPH_PSC --title \"$SUBREPORT $OPER\" --sub-heading $OPER --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$OPER.ps
				eval $GRAPH_PNG --logY --title \"$SUBREPORT $OPER\" --sub-heading $OPER --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$OPER-logY.png
				eval $GRAPH_PSC --logY --title \"$SUBREPORT $OPER\" --sub-heading $OPER --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$OPER-logY.ps
				plain graph-$SUBREPORT-$OPER
				plain graph-$SUBREPORT-$OPER-logY
				echo "</tr>"
			done
			;;
		pgbench)
			echo "<tr>"
			eval $GRAPH_PNG --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"

			generate_client_trans_graphs
			;;
		pistress)
			;;
		postmark)
			generate_basic "$SUBREPORT" "--logY"
			;;
		reaim)
			generate_client_subtest_graphs
			;;
		redis)
			generate_ops_graphs
			;;
		schbench)
			;;
		sembench-sem|sembench-nanosleep|sembench-futex)
			generate_basic "$SUBREPORT" "--logX --wide"
			;;
		siege)
			generate_basic "$SUBREPORT" "--logX"
			;;
		simoop)
			for INTERVAL in p50 p95 p99; do
				echo "<tr>"
				for HEADING in Read Write Allocation; do
					eval $GRAPH_PNG --title \"$SUBREPORT $INTERVAL-$HEADING\" --sub-heading $INTERVAL-$HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$INTERVAL-$HEADING.png
					eval $GRAPH_PSC --title \"$SUBREPORT $INTERVAL-$HEADING\" --sub-heading $INTERVAL-$HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$INTERVAL-$HEADING.ps
					plain graph-$SUBREPORT-$INTERVAL-$HEADING
				done
				echo "</tr>"
			done

			echo "<tr>"
			for HEADING in work stall; do
				eval $GRAPH_PNG -b simoop -a rates --title \"$SUBREPORT $HEADING rates\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$HEADING.png
				eval $GRAPH_PSC -b simoop -a rates --title \"$SUBREPORT $HEADING rates\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$HEADING.ps
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		sparsetruncate)
			echo "<tr>"
			generate_basic_single "$SUBREPORT truncation times"
			generate_basic_single "$SUBREPORT truncation times" "--logY"
			echo "</tr>"
			;;
		sockperf-tcp-under-load|sockperf-udp-under-load)
			generate_subtest_graphs_sorted
			;;
		speccpu2017-*-build)
			;;
		specjbb2013)
			;;
		sqlite)
			generate_subheading_trans_graphs "Trans" "sqlite"
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
		stockfish)
			echo "<tr>"
			eval $GRAPH_PNG        -b stockfish     --title \"$SUBREPORT nodes/sec\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC        -b stockfish     --title \"$SUBREPORT nodes/sec\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			eval $GRAPH_PNG        -b stockfish -a time --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-time.png
			eval $GRAPH_PSC        -b stockfish -a time --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-time.ps
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-time
			echo "</tr>"
			;;
		stutter)
			;;
		sysbench)
			echo "<tr>"
			eval $GRAPH_PNG --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			eval $GRAPH_PNG --logX -b sysbench -a exectime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime.png
			eval $GRAPH_PSC --logX -b sysbench -a exectime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime.ps
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-exectime
			echo "</tr>"
			;;
		sysjitter)
			for HEADING in int_total int_median int_mean; do
				eval $GRAPH_PNG --wide --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-${HEADING}.png
				eval $GRAPH_PNG --wide --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-${HEADING}.png
				echo "<tr>"
				plain graph-$SUBREPORT-$HEADING
				echo "</tr>"
			done
			;;
		tbench4)
			echo "<tr>"
			generate_basic_single "$SUBREPORT Throughput" "--logX"
			generate_basic_single "$SUBREPORT Throughput" "--logX --logY"
			generate_client_trans_graphs "`$COMPARE_BARE_CMD | grep ^Min | awk '{print $2}' | sort -n | uniq`" "Estimated time"
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
		unixbench-dhry2reg|unixbench-syscall|unixbench-pipe|unixbench-spawn|unixbench-execl)
			echo "<tr>"
			eval $GRAPH_PNG --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.png
			eval $GRAPH_PSC --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}.ps
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		usemem)
			echo "<tr>"
			for HEADING in Elapsd System; do
				eval $GRAPH_PNG -b usemem --title \"$SUBREPORT $HEADING time\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$HEADING.png
				eval $GRAPH_PSC -b usemem --title \"$SUBREPORT $HEADING time\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$HEADING.ps
			done
			plain graph-$SUBREPORT-System
			plain graph-$SUBREPORT-Elapsd
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
			SUB_WORKLOADS=
			if [ "$SUB_WORKLOADS_FILENAME" != "" ]; then
				SUB_WORKLOADS=`cat $SUB_WORKLOADS_FILENAME | sed -e 's/,/ /g'`
			fi
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
		wptlbflush)
			for CLIENT in `$COMPARE_BARE_CMD | grep ^Min | awk '{print $2}' | sed -e 's/.*-//' | sort -n | uniq`; do
				echo "<tr>"
				eval $GRAPH_PNG -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT.png
				eval $GRAPH_PSC -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT.ps
				eval $GRAPH_PNG -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT-smooth.png --smooth
				eval $GRAPH_PSC -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT-smooth.ps --smooth
				eval $GRAPH_PNG -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs sorted\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT-sorted.png --sort-samples-reverse
				eval $GRAPH_PSC -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs sorted\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT-sorted.ps --sort-samples-reverse
				smoothover graph-$SUBREPORT-$CLIENT
				plain graph-$SUBREPORT-$CLIENT-sorted
				echo "</tr>"
			done
			;;
		xfsrepair)
			;;
		*)
			eval $GRAPH_PNG --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.png
			eval $GRAPH_PSC --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT.ps
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

		if [ "$IOSTAT_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
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
		rm -f /tmp/iostat-$$

		if [ "$KCACHE_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
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
		rm -f /tmp/kcache.$$

		if [ "$FTRACE_ALLOCLATENCY_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"Direct reclaim allocation stalls\"   --print-monitor ftraceallocstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-alloc-stalls.png
			eval $GRAPH_PSC --title \"Direct reclaim allocation stalls\"   --print-monitor ftraceallocstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-alloc-stalls.ps
			eval $GRAPH_PNG --title \"Direct reclaim allocation stalls logY\"   --print-monitor ftraceallocstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-alloc-stalls-logY.png --logY
			eval $GRAPH_PSC --title \"Direct reclaim allocation stalls logY\"   --print-monitor ftraceallocstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-alloc-stalls-logY.ps --logY
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-alloc-stalls
			plain graph-$SUBREPORT-ftrace-alloc-stalls-logY
			echo "</tr>"
		fi

		if [ "$FTRACE_SHRINKERLATENCY_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"Slab shrinker stall kswapd\"       --print-monitor ftraceshrinkerstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd.png
			eval $GRAPH_PSC --title \"Slab shrinker stall kswapd\"       --print-monitor ftraceshrinkerstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd.ps
			eval $GRAPH_PNG --title \"Slab shrinker stall not kswapd\"   --print-monitor ftraceshrinkerstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd.png
			eval $GRAPH_PSC --title \"Slab shrinker stall not kswapd\"   --print-monitor ftraceshrinkerstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd.ps

			eval $GRAPH_PNG --title \"Slab shrinker stall kswapd logY\"       --print-monitor ftraceshrinkerstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd-logY.png --logY
			eval $GRAPH_PSC --title \"Slab shrinker stall kswapd logY\"       --print-monitor ftraceshrinkerstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd-logY.ps --logY
			eval $GRAPH_PNG --title \"Slab shrinker stall not kswapd logY\"   --print-monitor ftraceshrinkerstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd-logY.png --logY
			eval $GRAPH_PSC --title \"Slab shrinker stall not kswapd logY\"   --print-monitor ftraceshrinkerstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd-logY.ps --logY

			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd
			plain graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd-logY
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd
			plain graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd-logY
			echo "</tr>"
		fi

		if [ "$FTRACE_COMPACTLATENCY_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"Compaction stalls khugepaged\"                          --print-monitor ftracecompactstall --sub-heading khugepaged                     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-khugepaged.png
			eval $GRAPH_PNG --title \"Compaction stalls kswapd or kcompactd\"                 --print-monitor ftracecompactstall --sub-heading kswapd-kcompactd               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd.png
			eval $GRAPH_PNG --title \"Compaction stalls not khugepaged, kswapd or kcompactd\" --print-monitor ftracecompactstall --sub-heading no-kswapd-kcompactd-khugepaged --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged.png
			eval $GRAPH_PNG --title \"Compaction stalls khugepaged\"                          --print-monitor ftracecompactstall --sub-heading khugepaged                     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-khugepaged-logY.png --logY
			eval $GRAPH_PNG --title \"Compaction stalls kswapd or kcompactd logY\"                 --print-monitor ftracecompactstall --sub-heading kswapd-kcompactd               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd-logY.png --logY
			eval $GRAPH_PNG --title \"Compaction stalls not khugepaged, kswapd or kcompactd logY\" --print-monitor ftracecompactstall --sub-heading no-kswapd-kcompactd-khugepaged --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged-logY.png --logY

			eval $GRAPH_PSC --title \"Compaction stalls khugepaged\"                          --print-monitor ftracecompactstall --sub-heading khugepaged                     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-khugepaged.ps
			eval $GRAPH_PSC --title \"Compaction stalls kswapd or kcompactd\"                 --print-monitor ftracecompactstall --sub-heading kswapd-kcompactd               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd.ps
			eval $GRAPH_PSC --title \"Compaction stalls not khugepaged, kswapd or kcompactd\" --print-monitor ftracecompactstall --sub-heading no-kswapd-kcompactd-khugepaged --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged.ps
			eval $GRAPH_PSC --title \"Compaction stalls khugepaged logY\"                          --print-monitor ftracecompactstall --sub-heading khugepaged                      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-khugepaged-logY.ps --logY
			eval $GRAPH_PSC --title \"Compaction stalls kswapd or kcompactd logY\"                 --print-monitor ftracecompactstall --sub-heading kswapd-kcompactd               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd-logY.ps --logY
			eval $GRAPH_PSC --title \"Compaction stalls not khugepaged, kswapd or kcompactd logY\" --print-monitor ftracecompactstall --sub-heading no-kswapd-kcompactd-khugepaged --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged-logY.ps --logY

			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-compact-stalls-khugepaged
			plain graph-$SUBREPORT-ftrace-compact-stalls-khugepaged-logY
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd
			plain graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd-logY
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged
			plain graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged-logY
			echo "</tr>"
		fi

		if [ "$FTRACE_WAITIFFCONGESTED_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"wait_iff_congested stall kswapd\"       --print-monitor ftracewaitiffcongestedstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd.png
			eval $GRAPH_PSC --title \"wait_iff_congested stall kswapd\"       --print-monitor ftracewaitiffcongestedstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd.ps
			eval $GRAPH_PNG --title \"wait_iff_congested stall not kswapd\"   --print-monitor ftracewaitiffcongestedstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd.png
			eval $GRAPH_PSC --title \"wait_iff_congested stall not kswapd\"   --print-monitor ftracewaitiffcongestedstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd.ps

			eval $GRAPH_PNG --title \"wait_iff_congested stall kswapd logY\"       --print-monitor ftracewaitiffcongestedstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd-logY.png --logY
			eval $GRAPH_PSC --title \"wait_iff_congested stall kswapd logY\"       --print-monitor ftracewaitiffcongestedstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd-logY.ps --logY
			eval $GRAPH_PNG --title \"wait_iff_congested stall not kswapd logY\"   --print-monitor ftracewaitiffcongestedstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd-logY.png --logY
			eval $GRAPH_PSC --title \"wait_iff_congested stall not kswapd logY\"   --print-monitor ftracewaitiffcongestedstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd-logY.ps --logY

			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd
			plain graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd-logY
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd
			plain graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd-logY
			echo "</tr>"
		fi

		if [ "$FTRACE_CONGESTIONWAIT_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"congestion_wait stall kswapd\"       --print-monitor ftracecongestionwaitstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd.png
			eval $GRAPH_PSC --title \"congestion_wait stall kswapd\"       --print-monitor ftracecongestionwaitstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd.ps
			eval $GRAPH_PNG --title \"congestion_wait stall not kswapd\"   --print-monitor ftracecongestionwaitstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd.png
			eval $GRAPH_PSC --title \"congestion_wait stall not kswapd\"   --print-monitor ftracecongestionwaitstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd.ps

			eval $GRAPH_PNG --title \"congestion_wait stall kswapd logY\"       --print-monitor ftracecongestionwaitstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd-logY.png --logY
			eval $GRAPH_PSC --title \"congestion_wait stall kswapd logY\"       --print-monitor ftracecongestionwaitstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd-logY.ps --logY
			eval $GRAPH_PNG --title \"congestion_wait stall not kswapd logY\"   --print-monitor ftracecongestionwaitstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd-logY.png --logY
			eval $GRAPH_PSC --title \"congestion_wait stall not kswapd logY\"   --print-monitor ftracecongestionwaitstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd-logY.ps --logY

			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd
			plain graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd-logY
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd
			plain graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd-logY
			echo "</tr>"
		fi

		if [ "$FTRACE_BALANCEDIRTYPAGES_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"Balance Dirty Pages stalls : worst-case not actual and assumes HZ=250\"   --print-monitor ftracebalancedirtypagesstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-balancedirtypages-stalls.png
			eval $GRAPH_PSC --title \"Balance Dirty Pages stalls : worst-case not actual and assumes HZ=250\"   --print-monitor ftracebalancedirtypagesstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-balancedirtypages-stalls.ps
			eval $GRAPH_PNG --title \"Balance Dirty Pages stalls : worst-case not actual and assumes HZ=250 logY\"   --print-monitor ftracebalancedirtypagesstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-balancedirtypages-stalls-logY.png --logY
			eval $GRAPH_PSC --title \"Balance Dirty Pages stalls : worst-case not actual and assumes HZ=250 logY\"   --print-monitor ftracebalancedirtypagesstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-balancedirtypages-stalls-logY.ps --logY
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-balancedirtypages-stalls
			plain graph-$SUBREPORT-ftrace-balancedirtypages-stalls-logY
			echo "</tr>"
		fi

		# Monitor graphs for this test
		echo "<table class=\"monitorGraphs\">"
		generate_latency_graph "read-latency" '"Read Latency"'
		generate_latency_graph "write-latency" '"Write Latency"'
		generate_latency_graph "inbox-open" '"Mail Read Latency"'
		generate_latency_graph "sync-latency" '"Sync Latency"'

		if have_monitor_results iotop $KERNEL_BASE; then
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
						grep -F " $PROCESS " /tmp/iotop-mmtests-$$/$KERNEL-data | awk '{print $1" "$3}' > /tmp/iotop-mmtests-$$/$PRETTY
						if [ `cat /tmp/iotop-mmtests-$$/$PRETTY | wc -l` -gt 0 ]; then
							PROCESS_LIST="$PROCESS_LIST /tmp/iotop-mmtests-$$/$PRETTY"
							if [ "$TITLE_LIST" = "" ]; then
								TITLE_LIST=$PRETTY
							else
								TITLE_LIST="$TITLE_LIST,$PRETTY"
							fi
						fi
					done
					if [ "$PROCESS_LIST" != "" ]; then
						eval plot --yrange 0:$MAX --title \"$KERNEL process $OP activity\" --plottype points --titles \"$TITLE_LIST\" --format png         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-${KERNEL}.png $PROCESS_LIST
						if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
							eval plot --yrange 0:$MAX --title \"$KERNEL process $OP activity\" --plottype points --titles \"$TITLE_LIST\" --format postscript  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-${KERNEL}.ps $PROCESS_LIST
						fi
						plain graph-$SUBREPORT-iotop-$OP-$KERNEL
					else
						echo "<td><center>No IO activity $KERNEL $OP</center></td>"
					fi

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
					IOMAX=`awk '{print $3*100}' /tmp/iotop-mmtests-$$/$KERNEL-data | max`
					if [ "$IOMAX" = "NaN" ]; then
						IOMAX=0
					fi
					if [ $IOMAX -gt 0 ]; then
						eval plot --logY --title \"$KERNEL thread-$CALC $OP\" --plottype points --titles \"$TITLE_LIST\" --format png         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC.png $PLOT_LIST
						eval plot --title \"$KERNEL thread-$CALC $OP\" --plottype lines --titles \"$TITLE_LIST\" --format png         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC-smooth.png --smooth bezier $PLOT_LIST 
						if [ "$POSTSCRIPT_OUTPUT" != "no" ]; then
							eval plot --logY --title \"$KERNEL thread-$CALC $OP\" --plottype points --titles \"$TITLE_LIST\" --format postscript  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC.ps $PLOT_LIST
							eval plot --title \"$KERNEL thread-$CALC $OP\" --plottype lines --titles \"$TITLE_LIST\" --format postscript  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC-smooth.ps --smooth bezier $PLOT_LIST
						fi
						smoothover graph-$SUBREPORT-iotop-$OP-$CALC
					else
						echo "<td><center>No notable variation $OP-$CALC</center></td>"
					fi
				done
				echo "</tr>"
			done

			rm -rf /tmp/iotop-mmtests-$$
		fi

		if have_monitor_results turbostat $KERNEL_BASE; then
			EVENTS=`$EXTRACT_CMD -n $KERNEL_BASE --print-monitor turbostat --print-header | head -1 | sed -e 's/Time //'`
			COUNT=-1
			for EVENT in $EVENTS; do
				EVENT_FILENAME=`echo $EVENT | sed -e 's/%/Pct/g'`
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				RANGE_CMD="--yrange 0:100"
				if [ "$EVENT" = "CorrWatt" -o "$EVENT" = "PkgWatt" -o "$EVENT" = "Avg_MHz" ]; then
					RANGE_CMD=
				fi
				eval $GRAPH_PNG --title \"$EVENT\"   $RANGE_CMD --print-monitor turbostat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-turbostat-$EVENT_FILENAME.png
				eval $GRAPH_PSC --title \"$EVENT\"   $RANGE_CMD --print-monitor turbostat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-turbostat-$EVENT_FILENAME.ps
				eval $GRAPH_PNG --title \"$EVENT\"   $RANGE_CMD --print-monitor turbostat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-turbostat-$EVENT_FILENAME-smooth.png --smooth
				eval $GRAPH_PSC --title \"$EVENT\"   $RANGE_CMD --print-monitor turbostat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-turbostat-$EVENT_FILENAME-smooth.ps --smooth
				smoothover graph-$SUBREPORT-turbostat-$EVENT_FILENAME
				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi
		fi


		if have_monitor_results perf-time-stat $KERNEL_BASE; then
			EVENTS=`$EXTRACT_CMD -n $KERNEL_BASE --print-monitor perf-time-stat --print-header | head -1`
			COUNT=-1
			for EVENT in $EVENTS; do
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				eval $GRAPH_PNG --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT.png
				eval $GRAPH_PSC --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT.ps
				eval $GRAPH_PNG --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT-smooth.png --smooth
				eval $GRAPH_PSC --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT-smooth.ps --smooth
				smoothover graph-$SUBREPORT-perf-time-stat-$EVENT
				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi
		fi

		if have_monitor_results vmstat $KERNEL_BASE; then
			eval $GRAPH_PNG --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us.png
			eval $GRAPH_PSC --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us.ps
			eval $GRAPH_PNG --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy.png
			eval $GRAPH_PSC --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy.ps
			eval $GRAPH_PNG --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-wa.png 2> /dev/null
			eval $GRAPH_PSC --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ay.ps 2> /dev/null
			eval $GRAPH_PNG --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us-smooth.png --smooth
			eval $GRAPH_PSC --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us-smooth.ps  --smooth
			eval $GRAPH_PNG --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy-smooth.png --smooth
			eval $GRAPH_PSC --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy-smooth.ps  --smooth
			eval $GRAPH_PNG --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-wa-smooth.png --smooth 2> /dev/null
			eval $GRAPH_PSC --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ay-smooth.ps  --smooth 2> /dev/null

			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-us
			smoothover graph-$SUBREPORT-vmstat-sy
			smoothover graph-$SUBREPORT-vmstat-wa
			echo "</tr>"

			eval $GRAPH_PNG --title \"Runnable Processes\"   --print-monitor vmstat --sub-heading r --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-r.png
			eval $GRAPH_PSC --title \"Runnable Processes\"   --print-monitor vmstat --sub-heading r --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-r.ps
			eval $GRAPH_PNG --title \"Blocked Processes\"    --print-monitor vmstat --sub-heading b --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-b.png
			eval $GRAPH_PSC --title \"Blocked Processes\"    --print-monitor vmstat --sub-heading b --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-b.ps
			eval $GRAPH_PNG --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu.png
			eval $GRAPH_PSC --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu.ps
			eval $GRAPH_PNG --title \"Runnable Processes\"   --print-monitor vmstat --sub-heading r --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-r-smooth.png --smooth
			eval $GRAPH_PSC --title \"Runnable Processes\"   --print-monitor vmstat --sub-heading r --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-r-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Blocked Processes\"    --print-monitor vmstat --sub-heading b --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-b-smooth.png --smooth
			eval $GRAPH_PSC --title \"Blocked Processes\"    --print-monitor vmstat --sub-heading b --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-b-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu-smooth.png --smooth
			eval $GRAPH_PSC --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu-smooth.ps --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-r
			smoothover graph-$SUBREPORT-vmstat-b
			smoothover graph-$SUBREPORT-vmstat-totalcpu
			echo "</tr>"

			eval $GRAPH_PNG --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy.png
			eval $GRAPH_PSC --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy.ps
			eval $GRAPH_PNG --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy-smooth.png --smooth
			eval $GRAPH_PSC --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy-smooth.ps --smooth

			if have_monitor_results proc-vmstat $KERNEL_BASE; then
				eval $GRAPH_PNG --title \"Minor Faults\" --logY   --print-monitor proc-vmstat --sub-heading mmtests_minor_faults --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults.png
				eval $GRAPH_PSC --title \"Minor Faults\" --logY   --print-monitor proc-vmstat --sub-heading mmtests_minor_faults --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults.ps
				eval $GRAPH_PNG --title \"Major Faults\" --logY   --print-monitor proc-vmstat --sub-heading pgmajfault --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-majorfaults.png
				eval $GRAPH_PSC --title \"Major Faults\" --logY   --print-monitor proc-vmstat --sub-heading pgmajfault --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-majorfaults.ps

				eval $GRAPH_PNG --title \"Minor Faults\"          --print-monitor proc-vmstat --sub-heading mmtests_minor_faults --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults-smooth.png --smooth
				eval $GRAPH_PSC --title \"Minor Faults\"          --print-monitor proc-vmstat --sub-heading mmtests_minor_faults --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults-smooth.ps  --smooth
				eval $GRAPH_PNG --title \"Major Faults\"          --print-monitor proc-vmstat --sub-heading pgmajfault --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-majorfaults-smooth.png
				eval $GRAPH_PSC --title \"Major Faults\"          --print-monitor proc-vmstat --sub-heading pgmajfault --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-majorfaults-smooth.ps
			fi
			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-ussy
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults.png ]; then
				smoothover graph-$SUBREPORT-proc-vmstat-minorfaults
			fi
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-majorfaults.png ]; then
				MAJFAULTS=`$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading pgmajfault | awk '{print $2}' | max`
				if [ $MAJFAULTS -gt 0 ]; then
					smoothover graph-$SUBREPORT-proc-vmstat-majorfaults
				else
					echo "<td><center>No major page faults</center></td>"
				fi
			fi
			echo "</tr>"
		fi

		if have_monitor_results vmstat $KERNEL_BASE; then
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
		if have_monitor_results proc-vmstat $KERNEL_BASE; then
			eval $GRAPH_PNG --title \"Dirty Pages\"    --print-monitor proc-vmstat --sub-heading nr_dirty --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty.png 2> /dev/null
			eval $GRAPH_PSC --title \"Dirty Pages\"    --print-monitor proc-vmstat --sub-heading nr_dirty --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty.ps 2> /dev/null
			eval $GRAPH_PNG --title \"Writeback Pages\"    --print-monitor proc-vmstat --sub-heading nr_writeback --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_writeback.png 2> /dev/null
			eval $GRAPH_PSC --title \"Writeback Pages\"    --print-monitor proc-vmstat --sub-heading nr_writeback --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_writeback.ps 2> /dev/null
			eval $GRAPH_PNG --title \"Dirty Background Threshold\"    --print-monitor proc-vmstat --sub-heading nr_dirty_background_threshold --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty_background_threshold.png 2> /dev/null
			eval $GRAPH_PSC --title \"Dirty Background Threshold\"    --print-monitor proc-vmstat --sub-heading nr_dirty_background_threshold --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty_background_threshold.ps 2> /dev/null
			eval $GRAPH_PNG --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp.png 2> /dev/null
			eval $GRAPH_PSC --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp.ps 2> /dev/null
			eval $GRAPH_PNG --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon.png
			eval $GRAPH_PSC --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon.ps
			eval $GRAPH_PNG --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file.png
			eval $GRAPH_PSC --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file.ps
			eval $GRAPH_PNG --title \"Slab Unreclaimable pages\"    --print-monitor proc-vmstat --sub-heading nr_slab_unreclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-unreclaimable.png
			eval $GRAPH_PSC --title \"Slab Unreclaimable pages\"    --print-monitor proc-vmstat --sub-heading nr_slab_unreclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-unreclaimable.ps
			eval $GRAPH_PNG --title \"Slab Reclaimable pages\"    --print-monitor proc-vmstat --sub-heading nr_slab_reclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-reclaimable.png
			eval $GRAPH_PSC --title \"Slab Reclaimable pages\"    --print-monitor proc-vmstat --sub-heading nr_slab_reclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-reclaimable.ps
			eval $GRAPH_PNG --title \"Total slab pages\"    --print-monitor proc-vmstat --sub-heading mmtests_total_slab --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab.png
			eval $GRAPH_PSC --title \"Total slab pages\"    --print-monitor proc-vmstat --sub-heading mmtests_total_slab --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab.ps

			eval $GRAPH_PNG --title \"Dirty Pages\"    --print-monitor proc-vmstat --sub-heading nr_dirty --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty-smooth.png --smooth 2> /dev/null
			eval $GRAPH_PSC --title \"Dirty Pages\"    --print-monitor proc-vmstat --sub-heading nr_dirty --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty-smooth.ps --smooth 2> /dev/null
			eval $GRAPH_PNG --title \"Writeback Pages\"    --print-monitor proc-vmstat --sub-heading nr_writeback --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_writeback-smooth.png --smooth 2> /dev/null
			eval $GRAPH_PSC --title \"Writeback Pages\"    --print-monitor proc-vmstat --sub-heading nr_writeback --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_writeback-smooth.ps --smooth 2> /dev/null
			eval $GRAPH_PNG --title \"Dirty Background Threshold\"    --print-monitor proc-vmstat --sub-heading nr_dirty_background_threshold --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty_background_threshold-smooth.png --smooth 2> /dev/null
			eval $GRAPH_PSC --title \"Dirty Background Threshold\"    --print-monitor proc-vmstat --sub-heading nr_dirty_background_threshold --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty_background_threshold-smooth.ps --smooth 2> /dev/null
			eval $GRAPH_PNG --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp-smooth.png --smooth 2> /dev/null
			eval $GRAPH_PSC --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp-smooth.ps  --smooth 2> /dev/null
			eval $GRAPH_PNG --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon-smooth.png                --smooth
			eval $GRAPH_PSC --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon-smooth.ps                 --smooth
			eval $GRAPH_PNG --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file-smooth.png                --smooth
			eval $GRAPH_PSC --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file-smooth.ps                 --smooth
			eval $GRAPH_PNG --title \"Slab Unreclaimable pages\" --print-monitor proc-vmstat --sub-heading nr_slab_unreclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-unreclaimable-smooth.png --smooth
			eval $GRAPH_PSC --title \"Slab Unreclaimable pages\" --print-monitor proc-vmstat --sub-heading nr_slab_unreclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-unreclaimable-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Slab Reclaimable pages\" --print-monitor proc-vmstat --sub-heading nr_slab_reclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-reclaimable-smooth.png --smooth
			eval $GRAPH_PSC --title \"Slab Reclaimable pages\" --print-monitor proc-vmstat --sub-heading nr_slab_reclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-reclaimable-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Total slab pages\"    --print-monitor proc-vmstat --sub-heading mmtests_total_slab --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-smooth.png --smooth
			eval $GRAPH_PSC --title \"Total slab pages\"    --print-monitor proc-vmstat --sub-heading mmtests_total_slab --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-smooth.ps --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-nr_dirty
			smoothover graph-$SUBREPORT-proc-vmstat-nr_writeback
			smoothover graph-$SUBREPORT-proc-vmstat-nr_dirty_background_threshold
			echo "</tr>"

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-thp
			smoothover graph-$SUBREPORT-proc-vmstat-anon
			smoothover graph-$SUBREPORT-proc-vmstat-file
			echo "</tr>"
			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-slab-unreclaimable
			smoothover graph-$SUBREPORT-proc-vmstat-slab-reclaimable
			smoothover graph-$SUBREPORT-proc-vmstat-slab
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

			if [ "$SWAP_GRAPH" = "yes" ]; then
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
		fi

		KSWAPD_ACTIVITY=no
		DIRECT_ACTIVITY=no
		SLAB_ACTIVITY=no
		KSWAPD_INODE_STEAL_ACTIVITY=no
		DIRECT_INODE_STEAL_ACTIVITY=no
		if have_monitor_results proc-vmstat $KERNEL_BASE; then
			for KERNEL in $KERNEL_LIST_ITER; do
				$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan | grep -q -v " 0"
				if [ $? -eq 0 ]; then
					KSWAPD_ACTIVITY=yes
				fi
				$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading mmtests_direct_scan | grep -q -v " 0"
				if [ $? -eq 0 ]; then
					DIRECT_ACTIVITY=yes
				fi
				$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading slabs_scanned | grep -q -v " 0"
				if [ $? -eq 0 ]; then
					SLAB_ACTIVITY=yes

					$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading kswapd_inodesteal | grep -q -v " 0"
					if [ $? -eq 0 ]; then
						KSWAPD_INODE_STEAL_ACTIVITY=yes
					fi
					$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading pginodesteal | grep -q -v " 0"
					if [ $? -eq 0 ]; then
						DIRECT_INODE_STEAL_ACTIVITY=yes
					fi
				fi

			done
		fi
		if [ "$DIRECT_ACTIVITY" = "yes" ]; then
			eval $GRAPH_PNG --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan.png
			eval $GRAPH_PSC --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan.ps
			eval $GRAPH_PNG --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan-smooth.png --smooth
			eval $GRAPH_PSC --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal.png
			eval $GRAPH_PSC --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal.ps
			eval $GRAPH_PNG --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal-smooth.png --smooth
			eval $GRAPH_PSC --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal-smooth.ps --smooth
			eval $GRAPH_PNG --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency.png 2> /dev/null
			eval $GRAPH_PSC --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency.ps 2> /dev/null
			eval $GRAPH_PNG --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency-smooth.png --smooth 2> /dev/null
			eval $GRAPH_PSC --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency-smooth.ps --smooth 2> /dev/null
			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-direct-scan
			smoothover graph-$SUBREPORT-proc-vmstat-direct-steal
			smoothover graph-$SUBREPORT-proc-vmstat-direct-efficiency
			echo "</tr>"
		fi

		if [ "$KSWAPD_ACTIVITY" = "yes" ]; then
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

		if [ "$SLAB_ACTIVITY" = "yes" ]; then
			eval $GRAPH_PNG --title \"Slabs scanned\"       --print-monitor proc-vmstat --sub-heading slabs_scanned      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slabs-scanned.png
			eval $GRAPH_PSC --title \"Slabs scanned\"       --print-monitor proc-vmstat --sub-heading slabs_scanned      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slabs-scanned.ps
			if [ "$KSWAPD_INODE_STEAL_ACTIVITY" = "yes" ]; then
				eval $GRAPH_PNG --title \"Kswapd inode steal\"  --print-monitor proc-vmstat --sub-heading kswapd_inodesteal  --logY --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-inode-steal.png
				eval $GRAPH_PSC --title \"Kswapd inode steal\"  --print-monitor proc-vmstat --sub-heading kswapd_inodesteal  --logY --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-inode-steal.ps
			fi
			if [ "$DIRECT_INODE_STEAL_ACTIVITY" = "yes" ]; then
				eval $GRAPH_PNG --title \"Direct inode steal\"  --print-monitor proc-vmstat --sub-heading pginodesteal       --logY --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-inode-steal.png
				eval $GRAPH_PSC --title \"Direct inode steal\"  --print-monitor proc-vmstat --sub-heading pginodesteal       --logY --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-inode-steal.ps
			fi

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-slabs-scanned
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-inode-steal.png ]; then
				smoothover graph-$SUBREPORT-proc-vmstat-kswapd-inode-steal
			else
				echo "<td><center>No kswapd inode steal activity</center></td>"
			fi
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-inode-steal.png ]; then
				smoothover graph-$SUBREPORT-proc-vmstat-direct-inode-steal
			else
				echo "<td><center>No direct inode steal activity</center></td>"
			fi

			echo "</tr>"
		fi

		if have_monitor_results proc-vmstat $KERNEL_BASE "^compact_stall [1-9]"; then
			eval $GRAPH_PNG --title \"Compaction stall\"          --print-monitor proc-vmstat --sub-heading compact_stall      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_stall.png
			eval $GRAPH_PSC --title \"Compaction stall\"          --print-monitor proc-vmstat --sub-heading compact_stall      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_stall.ps
			eval $GRAPH_PNG --title \"Compaction stall\"          --print-monitor proc-vmstat --sub-heading compact_stall      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_stall-smooth.png --smooth
			eval $GRAPH_PSC --title \"Compaction stall\"          --print-monitor proc-vmstat --sub-heading compact_stall      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_stall-smooth.ps  --smooth

			eval $GRAPH_PNG --title \"Pages successful migrate\"  --print-monitor proc-vmstat --sub-heading pgmigrate_success  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success.png
			eval $GRAPH_PSC --title \"Pages successful migrate\"  --print-monitor proc-vmstat --sub-heading pgmigrate_success  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success.ps
			eval $GRAPH_PNG --title \"Pages successful migrate\"  --print-monitor proc-vmstat --sub-heading pgmigrate_success  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success-smooth.png --smooth
			eval $GRAPH_PSC --title \"Pages successful migrate\"  --print-monitor proc-vmstat --sub-heading pgmigrate_success  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success-smooth.ps  --smooth

			eval $GRAPH_PNG --title \"Pages failed migrate\"      --print-monitor proc-vmstat --sub-heading pgmigrate_fail     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_failure.png
			eval $GRAPH_PSC --title \"Pages failed migrate\"      --print-monitor proc-vmstat --sub-heading pgmigrate_fail     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_failure.ps
			eval $GRAPH_PNG --title \"Pages failed migrate\"      --print-monitor proc-vmstat --sub-heading pgmigrate_fail     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_failure-smooth.png --smooth
			eval $GRAPH_PSC --title \"Pages failed migrate\"      --print-monitor proc-vmstat --sub-heading pgmigrate_fail     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_failure-smooth.ps  --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-compact_stall
			smoothover graph-$SUBREPORT-proc-vmstat-pgmigrate_success
			smoothover graph-$SUBREPORT-proc-vmstat-pgmigrate_failure
			echo "</tr>"
		fi

		if have_monitor_results proc-vmstat $KERNEL_BASE "^numa_hint_faults [1-9]"; then
			eval $GRAPH_PNG --title \"NUMA PTE Updates\"       --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates.png
			eval $GRAPH_PSC --title \"NUMA PTE Updates\"       --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates.ps
			eval $GRAPH_PNG --title \"NUMA PTE Updates\"       --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA PTE Updates\"       --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates-smooth.ps --smooth

			eval $GRAPH_PNG --title \"NUMA Huge PTE Updates\"  --print-monitor proc-vmstat     --sub-heading numa_huge_pte_updates --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-huge-pte-updates.png
			eval $GRAPH_PSC --title \"NUMA Huge PTE Updates\"  --print-monitor proc-vmstat     --sub-heading numa_huge_pte_updates --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-huge-pte-updates.ps
			eval $GRAPH_PNG --title \"NUMA Huge PTE Updates\"  --print-monitor proc-vmstat     --sub-heading numa_huge_pte_updates --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-huge-pte-updates-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA Huge PTE Updates\"  --print-monitor proc-vmstat     --sub-heading numa_huge_pte_updates --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-huge-pte-updates-smooth.ps --smooth

			eval $GRAPH_PNG --title \"NUMA Migrations\"        --print-monitor proc-vmstat     --sub-heading numa_pages_migrated   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa_pages_migrated.png
			eval $GRAPH_PSC --title \"NUMA Migrations\"        --print-monitor proc-vmstat     --sub-heading numa_pages_migrated   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa_pages_migrated.ps
			eval $GRAPH_PNG --title \"NUMA Migrations\"        --print-monitor proc-vmstat     --sub-heading numa_pages_migrated   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa_pages_migrated-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA Migrations\"        --print-monitor proc-vmstat     --sub-heading numa_pages_migrated   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa_pages_migrated-smooth.ps --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-numa-pte-updates
			smoothover graph-$SUBREPORT-proc-vmstat-numa-huge-pte-updates
			smoothover graph-$SUBREPORT-proc-vmstat-numa_pages_migrated
			echo "</tr>"

			eval $GRAPH_PNG --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local.png
			eval $GRAPH_PSC --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local.ps
			eval $GRAPH_PNG --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA Hints Local\"    --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local-smooth.ps --smooth
			eval $GRAPH_PNG --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading mmtests_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote.png
			eval $GRAPH_PSC --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading mmtests_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote.ps
			eval $GRAPH_PNG --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading mmtests_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote-smooth.png --smooth
			eval $GRAPH_PSC --title \"NUMA Hints Remote\"   --print-monitor proc-vmstat --sub-heading mmtests_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote-smooth.ps --smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints-local
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints-remote
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults.png ]; then
				smoothover graph-$SUBREPORT-proc-vmstat-minorfaults
			fi
			echo "</tr>"
		fi

		if have_monitor_results numa-meminfo $KERNEL_BASE; then
			if [ `zgrep ^Node */numa-meminfo-* | awk '{print $2}' | sort | uniq | wc -l` -gt 1 ]; then
				eval $GRAPH_PNG --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance.png
				eval $GRAPH_PSC --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance.ps
				eval $GRAPH_PNG --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance-smooth.png --smooth
				eval $GRAPH_PSC --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance-smooth.ps --smooth
				eval $GRAPH_PNG --title \"NUMA Convergence\"    --print-monitor Numaconvergence                                   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-convergence.png
				eval $GRAPH_PSC --title \"NUMA Convergence\"    --print-monitor Numaconvergence                                   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-convergence.ps
				echo "<tr>"
				smoothover graph-$SUBREPORT-numa-memory-balance
				plain graph-$SUBREPORT-numa-convergence
				echo "</tr>"
			fi
		fi

		if have_monitor_results ftrace $KERNEL_BASE "mm_migrate_misplaced_pages"; then
			PLOT_TITLES=
			for NAME in `echo $KERNEL_LIST | sed -e 's/,/ /g'`; do
				cache-mmtests.sh extract-mmtests.pl -d . -b $SUBREPORT -n $NAME --print-monitor Ftracenumatraffic > /tmp/mmtests-numatraffic-$$-$NAME
				if [ "$PLOT_TITLES" = "" ]; then
					PLOT_TITLES=$NAME
				else
					PLOT_TITLES="$PLOT_TITLES $NAME"
				fi
			done
			MAX_MIGRATION=`awk '{print $3}' /tmp/mmtests-numatraffic-$$-* | sort -n | tail -1`
			MAX_NID=`awk '{print $2}' /tmp/mmtests-numatraffic-$$-* | sed -e 's/[a-z]*-//' | sort -n | tail -1`
			if [ "$MAX_NID" != "" ]; then
				PLOTTYPE=linespoints
				for NAME in `echo $KERNEL_LIST | sed -e 's/,/ /g'`; do
					echo "<tr>"
					for NID in `seq 0 $MAX_NID`; do
						grep "from-$NID " /tmp/mmtests-numatraffic-$$-$NAME | awk '{print $1" "$3}' > /tmp/mmtests-numatraffic-plot-$$-$NAME
						plot --yrange 0:$MAX_MIGRATION --title "NUMA balance page migrate from node $NID" --titles "$PLOT_TITLES" --plottype $PLOTTYPE --format png                               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numab-migrate-from-$NID-${NAME}.png /tmp/mmtests-numatraffic-plot-$$-$NAME
						plot --yrange 0:$MAX_MIGRATION --title "NUMA balance page migrate from node $NID" --titles "$PLOT_TITLES" --plottype $PLOTTYPE --format "postscript color solid" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numab-migrate-from-$NID-${NAME}.ps  /tmp/mmtests-numatraffic-plot-$$-$NAME
						plain graph-$SUBREPORT-numab-migrate-from-$NID-${NAME}
					done
					echo "</tr>"
					echo "<tr>"
					for NID in `seq 0 $MAX_NID`; do
						grep "to-$NID " /tmp/mmtests-numatraffic-$$-$NAME | awk '{print $1" "$3}' > /tmp/mmtests-numatraffic-plot-$$-$NAME
						plot --yrange 0:$MAX_MIGRATION --title "NUMA balance page migrate to node $NID" --titles "$PLOT_TITLES" --plottype $PLOTTYPE --format png                               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numab-migrate-to-$NID-${NAME}.png /tmp/mmtests-numatraffic-plot-$$-$NAME
						plot --yrange 0:$MAX_MIGRATION --title "NUMA balance page migrate to node $NID" --titles "$PLOT_TITLES" --plottype $PLOTTYPE --format "postscript color solid" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numab-migrate-to-$NID-${NAME}.ps  /tmp/mmtests-numatraffic-plot-$$-$NAME
						plain graph-$SUBREPORT-numab-migrate-to-$NID-${NAME}
					done
					echo "</tr>"
					rm /tmp/mmtests-numatraffic-plot-$$-$NAME
				done
			fi
			rm -f /tmp/mmtests-numatraffic-$$-*
		fi

		if have_monitor_results proc-net-dev $KERNEL_BASE; then
			INTERFACE_LIST=""
			if [ -e $KERNEL_BASE/ip-addr ]; then
				INTERFACE_LIST=`read-ip-addr.pl -u -f $KERNEL_BASE/ip-addr`
			else
				for NET_DEV in $KERNEL_BASE/proc-net-dev-*; do
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

		if have_monitor_results proc-interrupts $KERNEL_BASE; then
			echo "<table>"
			echo "<tr>"
			for HEADING in TLB-shootdowns Rescheduling-interrupts Function-call-interrupts; do
				eval $GRAPH_PNG --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING.png
				eval $GRAPH_PSC --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING.ps
				eval $GRAPH_PNG --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING-smooth.png --smooth
				eval $GRAPH_PSC --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING-smooth.ps  --smooth
				smoothover graph-$SUBREPORT-proc-interrupts-$HEADING
			done
			echo "</tr>"
			echo "<tr>"
			for HEADING in TLB-shootdowns Rescheduling-interrupts Function-call-interrupts; do
				eval $GRAPH_PNG --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING-logY.png --logY
				eval $GRAPH_PSC --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING-logY.ps --logY
				plain graph-$SUBREPORT-proc-interrupts-$HEADING-logY
			done
			echo "</tr>"
			echo "</table>"
		fi
	fi
done
cat $SCRIPTDIR/shellpacks/common-footer-$FORMAT 2> /dev/null
