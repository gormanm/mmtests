#!/bin/bash

export SCRIPTPATH=$(readlink -f "$0")
export SCRIPT=$(basename "$SCRIPTPATH")
export SCRIPTDIR=$(dirname "$SCRIPTPATH")
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/config
export PATH=$SCRIPTDIR/bin:$PATH

REPORT_TITLE=
OUTPUT_FILE=
IGNORE_FINGERPRINT=no
KERNEL_BASE=
KERNEL_COMPARE=
CHANGE_DIR=

install-depends perl-File-Which
install-depends python313-scipy

while [ "$1" != "" ]; do
	case $1 in
	-h|--help)
		perldoc ${BASH_SOURCE[0]}
		exit 0
		;;
	--auto-detect)
		AUTO_DETECT_SIGNIFICANCE="--print-significance"
		shift
		;;
	--format)
		FORMAT=$2
		FORMAT_CMD="--format $FORMAT"
		shift 2
		;;
	--output-dir|--output-directory)
		OUTPUT_DIRECTORY=$2
		mkdir -p $OUTPUT_DIRECTORY
		shift 2
		;;
	--output-file)
		OUTPUT_FILE=`basename $2`
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
	--from-json)
		FROM_JSON=yes
		JSON_FILE=$2
		shift 2
		;;
	--ignore-fingerprint)
		IGNORE_FINGERPRINT=yes
		shift
		;;
	--report-title)
		REPORT_TITLE="$2"
		shift 2
		;;
	--sort-version)
		SORT_VERSION=yes
		shift
		;;
	-C)
		CHANGE_DIR="$2"
		shift 2
		;;
	*)
		echo Unrecognised argument: $1 1>&2
		shift
		;;
	esac
done

OUT=/dev/stdout
if [ ! -t 1 ]; then
	OUT=$(mktemp ~/.compare-kernel-XXXX.out)
fi

if [ "$FORMAT" = "html" ]; then
	install-depends gnuplot &>> $OUT
	install-depends perl-GD &>> $OUT
fi

# Comment the following line if debugging and/or thinking that installing
# the packages above is having or causing issues and you want to see the output
[ "$OUT" != "/dev/stdout" ] && rm -f $OUT

if [ "$CHANGE_DIR" != "" ]; then
	cd "$CHANGE_DIR" || die "Failed to change to start directory $CHANGE_DIR"
fi

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
if [ "$OUTPUT_DIRECTORY" = "" -o "$OUTPUT_FILE" = "" ]; then
	IGNORE_FINGERPRINT=yes
fi

if [ "$FROM_JSON" != "yes" ]; then
	if ! have_run_results; then
		die "This does not look like a mmtests results directory"
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

REPORT_FINGERPRINT=
KERNEL_LIST_ITER=`echo $KERNEL_LIST | sed -e 's/,/ /g'`

# Use fingerprint to determine if report needs to be generated
if [ "$IGNORE_FINGERPRINT" = "no" ]; then
	TIMESTAMP_FILES=
	FIND_ARGS=
	for KERNEL in $KERNEL_LIST_ITER; do
		for TIMESTAMP_FILE in `find $KERNEL -name tests-timestamp | sort`; do
			TIMESTAMP_FILES+=" $TIMESTAMP_FILE"
		done
	done
	REPORT_FINGERPRINT=`cat $TIMESTAMP_FILES | md5sum | head -1 | cut -d\  -f1`

	OLD_FINGERPRINT=`cat $OUTPUT_DIRECTORY/report.md5 2>/dev/null`
	if [ "$OLD_FINGERPRINT" = "$REPORT_FINGERPRINT" ]; then
		if [ "$REPORT_TITLE" != "" ]; then
			REPORT_TITLE_PRINT=" '$REPORT_TITLE'"
		fi
		echo "Report$REPORT_TITLE_PRINT comparing '$KERNEL_LIST_ITER' is up to date"
		exit 0
	fi
fi

if [ "$OUTPUT_DIRECTORY" != "" -a "$OUTPUT_FILE" != "" ]; then
	exec > $OUTPUT_DIRECTORY/$OUTPUT_FILE
fi

cat $SCRIPTDIR/shellpacks/common-header-$FORMAT 2> /dev/null

# Print kernel command line options if they differ
FIRST=yes
FIRST_CMDLINE=
CMDLINE_DIFFER=no
rm -f /tmp/cmdline.$$
for KERNEL in $KERNEL_LIST_ITER; do
	if [ ! -e $KERNEL/iter-0/dmesg.gz ]; then
		continue
	fi
	CMDLINE=`extract-dmesg-cmdline $KERNEL/iter-0/dmesg.gz`
	if [ "$FIRST" = "yes" ]; then
		FIRST=no
		FIRST_CMDLINE="$CMDLINE"
	else
		if [ "$CMDLINE" != "$FIRST_CMDLINE" ]; then
			CMDLINE_DIFFER=yes
		fi
	fi
	printf "%-40s %s\n" "$KERNEL" "$CMDLINE" >> /tmp/cmdline.$$
done
if [ "$CMDLINE_DIFFER" = "yes" ]; then
	if [ "$FORMAT" = "html" ]; then
		echo "<a name="kernel-cmdline">"
		echo "<pre>"
	fi
	echo Test kernel command lines
	cat /tmp/cmdline.$$
	if [ "$FORMAT" = "html" ]; then
		echo "</pre>"
	fi
fi
rm -f /tmp/cmdline.$$

# Print LSM options
FIRST=yes
FIRST_LSM=
rm -f /tmp/lsm.$$
for KERNEL in $KERNEL_LIST_ITER; do
	if [ ! -e $KERNEL/iter-0/security-lsm ]; then
		LSM="(unavailable)"
	else
		LSM=`cat $KERNEL/iter-0/security-lsm`
	fi
	if [ "$FIRST" = "yes" ]; then
		FIRST=no
		FIRST_LSM="$LSM"
	else
		if [ "$LSM" != "$FIRST_LSM" ]; then
			LSM_DIFFER=yes
		fi
	fi
	printf "%-40s %s\n" "$KERNEL" "$LSM" >> /tmp/lsm.$$
done
if [ "$LSM_DIFFER" = "yes" ]; then
	if [ "$FORMAT" = "html" ]; then
		echo "<a name="lsm-enabled">"
		echo "<pre>"
	fi
	echo Test LSM module order
	cat /tmp/lsm.$$
	if [ "$FORMAT" = "html" ]; then
		echo "</pre>"
	fi
fi
rm -f /tmp/lsm.$$

# Print cstate information if different
FIRST=yes
FIRST_CPUIDLE=
rm -f /tmp/cpuidle.$$
for KERNEL in $KERNEL_LIST_ITER; do
	if [ ! -e $KERNEL/iter-0/cpuidle-latencies.txt ]; then
		CPUIDLE="(unavailable)"
	else
		CPUIDLE=`cat $KERNEL/iter-0/cpuidle-latencies.txt`
	fi
	if [ "$FIRST" = "yes" ]; then
		FIRST=no
		FIRST_CPUIDLE="$CPUIDLE"
	else
		if [ "$CPUIDLE" != "$FIRST_CPUIDLE" ]; then
			CPUIDLE_DIFFER=yes
		fi
	fi
	printf "CState exit latencies: %-40s\n%s\n" "$KERNEL" "$CPUIDLE" >> /tmp/cpuidle.$$
done
if [ "$CPUIDLE_DIFFER" = "yes" ]; then
	if [ "$FORMAT" = "html" ]; then
		echo "<a name="cpuidle-enabled">"
		echo "<pre>"
	fi
	echo Test CState latencies
	cat /tmp/cpuidle.$$
	if [ "$FORMAT" = "html" ]; then
		echo "</pre>"
	fi
fi
rm -f /tmp/cpuidle.$$

# Print IO storage details if available
FIRST=yes
for KERNEL in $KERNEL_LIST_ITER; do
	IODETAILS=`find $KERNEL -name "storageioqueue.txt"`
	if [ "$IODETAILS" != "" ]; then
		if [ "$FORMAT" = "html" ]; then
			echo "<a name="storageconfig">"
			echo "<pre>"
		fi

		if [ "$FIRST" = "yes" ]; then
			echo Storage scheduler
			FIRST=
		fi
		for FILE in $IODETAILS; do
			DETAILS=`grep -H scheduler: $FILE`
			KERNEL=`echo $DETAILS | awk -F / '{print $1}'`
			IOSCHED=`echo $DETAILS | awk -F : '{print $NF}'`
			printf "%-40s %s\n" "$KERNEL" "$IOSCHED"
		done

		if [ "$FORMAT" = "html" ]; then
			echo "</pre>"
		fi
	fi
done

plain() {
	IMG_SRC=$1
	WIDTH=$2
	if [ "$WIDTH" != "" ]; then
		WIDTH="width=$WIDTH "
	fi
	echo -n "  <td><img ${WIDTH}src=\"$IMG_SRC.png\"></td>"
}

plain_alone() {
	IMG_SRC=$1
	echo -n "  <td colspan=4><img src=\"$IMG_SRC.png\"></td>"
}

smoothover() {
	IMG_SRC=$1
	IMG_SMOOTH=$1-smooth
	echo -n "  <td><img src=\"$IMG_SRC.png\" onmouseover=\"this.src='$IMG_SMOOTH.png'\" onmouseout=\"this.src='$IMG_SRC.png'\"></td>"
}

logyover() {
	IMG_SRC=$1
	IMG_LOGY=$1-logY
	echo -n "  <td><img src=\"$IMG_LOGY.png\" onmouseover=\"this.src='$IMG_SRC.png'\" onmouseout=\"this.src='$IMG_LOGY.png'\"></td>"
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
		eval $GRAPH_PNG $GRANULARITY --title "$LATSTRING" --print-monitor $LATTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$LATTYPE --with-smooth
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
		eval $GRAPH_PNG --sub-heading $CLIENT --plottype lines --title \"$LABEL\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT_FILENAME} --x-label \"$XLABEL\" --with-smooth
		eval $GRAPH_PNG --sub-heading $CLIENT --plottype lines --title \"$LABEL sorted\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-trans-${CLIENT_FILENAME}-sorted --sort-samples-reverse --x-label \"Sorted samples\"
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
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
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
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
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
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME
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
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME
		eval $GRAPH_PNG --title \"$SUBREPORT $HEADING sorted\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME-sorted --sort-samples --sort-percentages 5
		if [ "$2" != "--logY" ]; then
			plain graph-$SUBREPORT-$HEADING_FILENAME
			plain graph-$SUBREPORT-$HEADING_FILENAME-sorted
		else
			eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME-logY --logY
			eval $GRAPH_PNG --title \"$SUBREPORT $HEADING sorted\" --sub-heading \"$HEADING\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING_FILENAME-sorted-logY --sort-samples --sort-percentages 5 --logY

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
			eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
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

	eval $GRAPH_PNG $EXTRA --title \"$TITLE$EXTRA_TITLE\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT$EXTRA_FILENAME
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
		eval $GRAPH_PNG -b $SUBTEST --title \"$SUBTEST $SUBHEADING\" $EXTRA --sub-heading $SUBHEADING  --output $OUTPUT_DIRECTORY/graph-$SUBTEST-$SUBHEADING
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
		eval $GRAPH_PNG -a $SUBTEST --title \"$SUBTEST $SUBHEADING\" $EXTRA --sub-heading $SUBHEADING  --output $OUTPUT_DIRECTORY/graph-$SUBTEST-$SUBHEADING --x-label Time --with-smooth
		eval $GRAPH_PNG -a $SUBTEST --title \"$SUBTEST $SUBHEADING sorted\" $EXTRA --sub-heading $SUBHEADING  --output $OUTPUT_DIRECTORY/graph-$SUBTEST-$SUBHEADING-sorted --sort-samples-reverse --x-label \"Sorted samples\"
		plain graph-$SUBTEST-$SUBHEADING
		plain graph-$SUBTEST-$SUBHEADING-smooth
		plain graph-$SUBTEST-$SUBHEADING-sorted
		echo "</tr>"
	done
}

if [ "$FROM_JSON" = "yes" ]; then
	JSON_FILES=(${JSON_FILE//,/ })
	JSON_FILE=${JSON_FILES[0]}
	REPORTS=$(reports-from-json.pl $JSON_FILE)
	SUBREPORTS_JSON=("${JSON_FILES[@]:1}")
else
	REPORTS=$(run_report_name $KERNEL_BASE)
fi

for SUBREPORT in $REPORTS; do
	if [ "$FROM_JSON" = "yes" ]; then
		OLD_KERNEL_LIST=$KERNEL_LIST
		KERNEL_LIST="NONE"
	fi
	EXTRACT_CMD="extract-mmtests.pl --format script -d . -b $SUBREPORT"
	COMPARE_CMD="compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD $AUTO_DETECT_SIGNIFICANCE"
	COMPARE_BARE_CMD="compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST"
	GRAPH_PNG="graph-mmtests.sh -d . -b $SUBREPORT -n $KERNEL_LIST --format png"
	if [ "$FROM_JSON" = "yes" ]; then
		OLD_COMPARE_CMD=$COMPARE_CMD
		COMPARE_CMD+=" --from-json $JSON_FILE"
	fi
	echo
	if [ "$FORMAT" = "html" ]; then
		echo "<a name="$SUBREPORT">"
		echo "<pre>"
	fi

	if [ "$OPTFILE_DISPLAYED" != "yes" ]; then
		OPTFILE_DISPLAYED=yes
		for OPTFILE in compiler.opts runtime.opts sysctl.opts; do
			OPTS=`find $KERNEL_BASE -maxdepth 4 -name "$OPTFILE" | head -1`
			if [ "$OPTS" != "" ]; then
				cat $OPTS | uniq
				echo
			fi
		done
	fi

	if [ "$FORMAT" = "html" ]; then
		echo "</pre>"
	fi

	case $SUBREPORT in
	cyclictest)
		echo $SUBREPORT
		eval $COMPARE_CMD
		echo

		for KERNEL in $KERNEL_LIST; do
			if [ `find $KERNEL -name cyclictest-histogram.log | wc -l` -gt 0 ]; then
				echo Cyclictest Histogram
				eval compare-mmtests.pl -d . -b cyclictest-histogram -n $KERNEL_LIST $FORMAT_CMD
			fi
			break
		done
		;;
	dbench4)
		echo $SUBREPORT Loadfile Execution Time
		eval $COMPARE_CMD
		echo
		if [ "$FROM_JSON" = "yes" ]; then
			SUBREPORT_NAMES=('Latency' 'Throughput (misleading but traditional)' 'Per-VFS Operation latency Latency')

			min=$(( ${#SUBREPORTS_JSON[@]} < ${#SUBREPORT_NAMES[@]} ?	${#SUBREPORTS_JSON[@]} : ${#SUBREPORT_NAMES[@]} ))
			for ((i=start; i<min; i++)) do
				echo "$SUBREPORT ${SUBREPORT_NAMES[$i]}"
				compare-mmtests.pl -d . -b dbench4 --from-json ${SUBREPORTS_JSON[$i]}
				echo
			done
		else
			echo "$SUBREPORT All Clients Loadfile Execution Time"
			compare-mmtests.pl -d . -b dbench4 -a completionlag -n $KERNEL_LIST $FORMAT_CMD
			echo
			echo "$SUBREPORT Loadfile Complete Spread (Max-Min completions between processes every second)"
			compare-mmtests.pl -d . -b dbench4 -a completions -n $KERNEL_LIST $FORMAT_CMD
			echo
			echo "$SUBREPORT Throughput (misleading but traditional)"
			compare-mmtests.pl -d . -b dbench4 -a tput -n $KERNEL_LIST $FORMAT_CMD
			echo
			echo $SUBREPORT Per-VFS Operation latency Latency
			compare-mmtests.pl -d . -b dbench4 -a opslatency -n $KERNEL_LIST $FORMAT_CMD
		fi
		;;
	bonniepp)
		echo "bonnie IO Execution Time"
		compare-mmtests.pl -d . -b bonniepp -n $KERNEL_LIST $FORMAT_CMD $AUTO_DETECT_SIGNIFICANCE
		echo
		echo "bonnie Throughput"
		compare-mmtests.pl -d . -b bonniepp -a tput -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	ebizzy)
		echo $SUBREPORT Overall Throughput
		$COMPARE_CMD
		echo
		echo $SUBREPORT Per-thread
		compare-mmtests.pl -d . -b ebizzy -a thread -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Thread spread
		compare-mmtests.pl -d . -b ebizzy -a range -n $KERNEL_LIST $FORMAT_CMD
		;;
	fio)
		echo $SUBREPORT Throughput
		$COMPARE_CMD
		echo
		echo $SUBREPORT Latency read
		compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b fio -a latency -n $KERNEL_LIST --sub-heading latency-read $FORMAT_CMD

		echo
		echo $SUBREPORT Latency write
		compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b fio -a latency -n $KERNEL_LIST --sub-heading latency-write $FORMAT_CMD
		echo
		# all sub-headings (ie. fio-scaling-[rand]{rw,read,write}-{read,write})
		echo $SUBREPORT scaling
		compare-mmtests.pl -d . -b fio -a scaling -n $KERNEL_LIST 2> /dev/null
		# all sub-headings (ie. fio-ssd-{rand|seq}_jobs_{1|4}-qd_{1|32}-bs_{4k|128k}-{read|write})
		echo $SUBREPORT ssd
		compare-mmtests.pl -d . -b fio -a ssd -n $KERNEL_LIST 2> /dev/null
		;;
	fsmark-single|fsmark-threaded)
		echo $SUBREPORT
		$COMPARE_CMD
		echo
		echo $SUBREPORT App Overhead
		compare-mmtests.pl -d . -b ${SUBREPORT}overhead -n $KERNEL_LIST $FORMAT_CMD
		;;
	hpcc)
		echo $SUBREPORT HPCC Time
		compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT HPCC Load Scores
		compare-mmtests.pl -d . -b ${SUBREPORT} -a score -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	johnripper)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo

		echo $SUBREPORT User/System CPU time
		compare-mmtests.pl -d . -b johnripper -a exectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	monitor)
		echo No meaningful extraction script for monitor
		echo
		;;
	multi)
		for MULTI_TEST in `cat $KERNEL_BASE/iter-0/multi/logs/multi.list`; do
			echo $SUBREPORT subtest $MULTI_TEST
			compare-mmtests.pl -d . -b $MULTI_TEST -n $KERNEL_LIST $FORMAT_CMD
			echo
		done
		;;
	nas*)
		echo $SUBREPORT NAS Time
		compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Wall Time
		compare-mmtests.pl -d . -b ${SUBREPORT} -a time -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	netperf-*)
		echo $SUBREPORT Default report
		compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD

		echo
		echo $SUBREPORT Over-time report
		compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD -a overtime
		echo
		;;
	netpipe)
		echo $SUBREPORT Throughput
		compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b netpipe -a 4mb -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	openfoam)
		echo $SUBREPORT Wall Time
		compare-mmtests.pl -d . -b $SUBREPORT -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Step Times
		compare-mmtests.pl -d . -b $SUBREPORT -a steps -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	parallelio)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Background IO
		compare-mmtests.pl -d . -b parallelio -a io -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Swap totals
		compare-mmtests.pl -d . -b parallelio -a swap -n $KERNEL_LIST $FORMAT_CMD
		;;
	parsecbuild)
		echo $SUBREPORT
		;;
	pft)
		echo $SUBREPORT timings
		compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b pft -a time -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT faults
		eval $COMPARE_CMD
		;;
	pgbench)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		compare-mmtests.pl $AUTO_DETECT_SIGNIFICANCE -d . -b pgbench -a stalls -n $KERNEL_LIST $FORMAT_CMD > /tmp/pgbench-$$
		TEST=`grep MinStall-1 /tmp/pgbench-$$ | grep -v nan`
		if [ "$TEST" != "" ]; then
			echo
			echo $SUBREPORT Stalls
			cat /tmp/pgbench-$$
		fi
		rm /tmp/pgbench-$$
		echo
		echo $SUBREPORT Time
		compare-mmtests.pl -d . -b pgbench -a exectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	redis-memtier)
		for HEADING in Ops/sec Hits/sec Miss/sec; do
			echo $SUBREPORT $HEADING
			eval $COMPARE_CMD --sub-heading `echo $HEADING | tr A-Z a-z`
			echo
		done
		;;
	schbench)
		for HEADING in Wakeup Request; do
			echo "$SUBREPORT $HEADING Latency (usec)"
			eval $COMPARE_CMD --sub-heading $HEADING
			echo
		done
		;;
	simoop)
		echo $SUBREPORT latencies
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT rates
		compare-mmtests.pl -d . -b simoop -a rates -n $KERNEL_LIST $FORMAT_CMD
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
		compare-mmtests.pl -d . -b stockfish -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Execution time
		compare-mmtests.pl -d . -b stockfish -a time -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	stutterp)
		echo $SUBREPORT
		$COMPARE_CMD
		echo
		echo $SUBREPORT estimated write speed
		compare-mmtests.pl -d . -b $SUBREPORT -a calibrate -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT parallel write throughput
		compare-mmtests.pl -d . -b $SUBREPORT -a throughput -n $KERNEL_LIST $FORMAT_CMD
		;;
	sysbench)
		echo $SUBREPORT Transactions
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Time
		compare-mmtests.pl -d . -b sysbench -a exectime -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	tbench4)
		echo $SUBREPORT Loadfile Execution Time
		eval $COMPARE_CMD
		echo
		if [ "$FROM_JSON" = "yes" ]; then
			SUBREPORT_NAMES=('Latency' 'Throughput (misleading but traditional)' 'Per-VFS Operation latency Latency')

			min=$(( ${#SUBREPORTS_JSON[@]} < ${#SUBREPORT_NAMES[@]} ?	${#SUBREPORTS_JSON[@]} : ${#SUBREPORT_NAMES[@]} ))
			for ((i=start; i<min; i++)) do
				echo "$SUBREPORT ${SUBREPORT_NAMES[$i]}"
				compare-mmtests.pl -d . -b tbench4 --from-json ${SUBREPORTS_JSON[$i]}
				echo
			done
		else
			echo "$SUBREPORT All Clients Loadfile Execution Time"
			compare-mmtests.pl -d . -b tbench4 -a completionlag -n $KERNEL_LIST $FORMAT_CMD
			echo
			echo "$SUBREPORT Loadfile Complete Spread (Max-Min completions between processes every second)"
			compare-mmtests.pl -d . -b tbench4 -a completions -n $KERNEL_LIST $FORMAT_CMD
			echo "$SUBREPORT Throughput (misleading but traditional)"
			compare-mmtests.pl -d . -b tbench4 -a tput -n $KERNEL_LIST $FORMAT_CMD
			echo
			echo $SUBREPORT Per-VFS Operation latency Latency
			compare-mmtests.pl -d . -b tbench4 -a opslatency -n $KERNEL_LIST $FORMAT_CMD
		fi
		;;

	trunc)
		echo $SUBREPORT Truncate files
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Fault files
		compare-mmtests.pl -d . -b trunc -a fault -n $KERNEL_LIST $FORMAT_CMD
		echo
		;;
	thpchallenge|thpcompact)
		echo $SUBREPORT Fault Latencies
		eval $COMPARE_CMD
		echo
		echo $SUBREPORT Percentage Faults Huge
		compare-mmtests.pl -d . -b $SUBREPORT -a counts -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Percentage Locality
		compare-mmtests.pl -d . -b $SUBREPORT -a locality -n $KERNEL_LIST $FORMAT_CMD
		;;
	xfsio)
		echo $SUBREPORT Time
		$COMPARE_CMD
		echo
		echo $SUBREPORT Throughput
		compare-mmtests.pl -d . -b xfsio -a throughput -n $KERNEL_LIST $FORMAT_CMD
		echo
		echo $SUBREPORT Ops
		compare-mmtests.pl -d . -b xfsio -a ops -n $KERNEL_LIST $FORMAT_CMD
		;;
	*)
		echo $SUBREPORT
		eval $COMPARE_CMD
	esac
	echo
	if [ "$FROM_JSON" = "yes" ]; then
		COMPARE_CMD=$OLD_COMPARE_CMD
		continue
	fi
	eval $COMPARE_CMD --print-monitor duration
	echo

	eval $COMPARE_CMD --print-monitor mmtests-vmstat
	echo
	eval $COMPARE_CMD --print-monitor mmtests-schedstat

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

	if have_monitor_results ftrace $KERNEL_BASE sched_migrate_task; then
		echo Ftrace task CPU migrations
		eval $COMPARE_CMD --print-monitor ftraceschedmigrate
		echo
	fi

	if have_monitor_results ftrace $KERNEL_BASE sched_stick_numa; then
		echo Ftrace NUMA Balancing migrations
		eval $COMPARE_CMD --print-monitor ftracenumabalance
		echo
	fi

	SWAP_GRAPH=no
	if have_monitor_results vmstat $KERNEL_BASE; then
		for EVENT in si so; do
			eval $COMPARE_CMD --print-monitor vmstat --sub-heading $EVENT | grep Max | grep -v 0.00 &> /dev/null
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
			SUBTEST_LIST=`$EXTRACT_CMD -n $KERNEL | awk '{print $1" "$2}' | sort | uniq | sed -e 's/ /@/g' -e 's/[0-9]//g'`
			generate_subtest_graphs_sorted "$SUBTEST_LIST" --logY
			;;
		autonumabench)
			echo "<tr>"
			for HEADING in elsp syst; do
				TITLE_HEADING=
				case $HEADING in
				syst)
					TITLE_HEADING="System"
					;;
				elsp)
					TITLE_HEADING="Elapsed"
					;;
				esac
				eval $GRAPH_PNG --title \"$SUBREPORT $TITLE_HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		blogbench)
			generate_subheading_graphs "Read Write"
			;;
		cyclictest)
			for HEADING in Max Avg; do
				eval $GRAPH_PNG --title \"$SUBREPORT Latency $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
				plain graph-$SUBREPORT-$HEADING
			done
			;;
		cyclictest-fine-*)
			eval $GRAPH_PNG --wide --logY --title \"$SUBREPORT Latency\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
			eval $GRAPH_PNG --wide --logX --logY --title \"$SUBREPORT Latency sorted\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING-sorted --sort-samples-reverse
			eval $GRAPH_PNG --very-large --logY --title \"$SUBREPORT Latency sorted\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING-sorted-percentage --sort-samples --sort-percentages 1 --rotate-xaxis
			eval $GRAPH_PNG --very-large --logY --title \"$SUBREPORT Latency sorted\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING-sorted-percentage-tail --sort-samples --sort-percentages 1 --xrange 99:100 --xtics 0.1 --rotate-xaxis
			eval $GRAPH_PNG --very-large --logY --title \"$SUBREPORT Latency sorted last 1%\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING-sorted-percentage-tail-99-100 --sort-samples --sort-percentages 1 --xrange 99:100 --xtics 0.1 --rotate-xaxis
			eval $GRAPH_PNG --very-large --title \"$SUBREPORT Latency sorted 95-99.9%\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING-sorted-percentage-tail-95-99 --sort-samples --sort-percentages 1 --xrange 95:99.9 --xtics 0.5 --rotate-xaxis
			echo "<tr>"
			plain graph-$SUBREPORT-$HEADING
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-$HEADING-sorted
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-$HEADING-sorted-percentage
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-$HEADING-sorted-percentage-tail-99-100
			echo "</tr>"
			echo "<tr>"
			plain graph-$SUBREPORT-$HEADING-sorted-percentage-tail-95-99
			echo "</tr>"
			;;
		pmqtest-pinned|pmqtest-unbound)
			for HEADING in Min Max Avg; do
				eval $GRAPH_PNG --title \"$SUBREPORT Latency $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
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
						eval $GRAPH_PNG --title \"$SUBREPORT $SUB_WORKLOAD $LOCKTYPE\" --sub-heading $SUB_WORKLOAD-$LOCKTYPE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$SUB_WORKLOAD-$LOCKTYPE
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
		futexbench-hash|futexbench-requeue|futexbench-requeue-pi|futexbench-wake|futexbench-wake-parallel|futexbench-lock-pi)
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
		abinit|frontistr|openfoam|specfem3d|wrf)
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
				eval $GRAPH_PNG --title \"$SUBREPORT $TITLE_HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
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
				eval $GRAPH_PNG --logX --title \"$SUBREPORT $TITLE_HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
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
			eval $GRAPH_PNG --xrange 16:32768 --logX --title \"$SUBREPORT Send Throughput\" --sub-heading send --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-send
			eval $GRAPH_PNG --xrange 16:32768 --logX --title \"$SUBREPORT Recv Throughput\" --sub-heading recv --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-recv
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
			eval $GRAPH_PNG --title \"$SUBREPORT faults/cpu\" --sub-heading faults/cpu --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-faultscpu
			eval $GRAPH_PNG --title \"$SUBREPORT faults/sec\" --sub-heading faults/sec --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-faultssec
			plain graph-$SUBREPORT-faultscpu
			plain graph-$SUBREPORT-faultssec
			echo "</tr>"
			;;
		pgioperfbench)
			for OPER in commit read wal; do
				echo "<tr>"
				eval $GRAPH_PNG --title \"$SUBREPORT $OPER\" --sub-heading $OPER --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$OPER
				eval $GRAPH_PNG --logY --title \"$SUBREPORT $OPER\" --sub-heading $OPER --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$OPER-logY
				plain graph-$SUBREPORT-$OPER
				plain graph-$SUBREPORT-$OPER-logY
				echo "</tr>"
			done
			;;
		pgbench)
			echo "<tr>"
			eval $GRAPH_PNG --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}
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
		redis*)
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
					eval $GRAPH_PNG --title \"$SUBREPORT $INTERVAL-$HEADING\" --sub-heading $INTERVAL-$HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$INTERVAL-$HEADING
					plain graph-$SUBREPORT-$INTERVAL-$HEADING
				done
				echo "</tr>"
			done

			echo "<tr>"
			for HEADING in work stall; do
				eval $GRAPH_PNG -b simoop -a rates --title \"$SUBREPORT $HEADING rates\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$HEADING
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
				eval $GRAPH_PNG --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$HEADING
				plain graph-$SUBREPORT-$HEADING
			done
			echo "</tr>"
			;;
		stockfish)
			echo "<tr>"
			eval $GRAPH_PNG        -b stockfish     --title \"$SUBREPORT nodes/sec\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}
			eval $GRAPH_PNG        -b stockfish -a time --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-time
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-time
			echo "</tr>"
			;;
		sysbench)
			echo "<tr>"
			eval $GRAPH_PNG --logX                    --title \"$SUBREPORT transactions\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}
			eval $GRAPH_PNG --logX -b sysbench -a exectime --title \"$SUBREPORT exec time\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-exectime
			plain graph-$SUBREPORT
			plain graph-$SUBREPORT-exectime
			echo "</tr>"
			;;
		sysjitter)
			for HEADING in int_total int_median int_mean; do
				eval $GRAPH_PNG --wide --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-${HEADING}
				eval $GRAPH_PNG --wide --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-${HEADING}
				echo "<tr>"
				plain graph-$SUBREPORT-$HEADING
				echo "</tr>"
			done
			;;
		vdsotest)
			for HEADING in syscall vdso; do
				eval $GRAPH_PNG --wide --title \"$SUBREPORT $HEADING\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-${HEADING}
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
		thpcompact)
			echo "<tr>"

			for SIZE in fault-base fault-huge; do
				eval $GRAPH_PNG        -b thpcompact --title \"$SUBREPORT $SIZE\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$SIZE --sub-heading $SIZE
				plain graph-$SUBREPORT-$SIZE
			done
			echo "</tr>"
			;;
		unixbench-dhry2reg|unixbench-syscall|unixbench-pipe|unixbench-spawn|unixbench-execl)
			echo "<tr>"
			eval $GRAPH_PNG --wide --logX --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}
			plain graph-$SUBREPORT
			echo "</tr>"
			;;
		usemem)
			echo "<tr>"
			for HEADING in Elapsd System; do
				eval $GRAPH_PNG -b usemem --title \"$SUBREPORT $HEADING time\" --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$HEADING
			done
			plain graph-$SUBREPORT-System
			plain graph-$SUBREPORT-Elapsd
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
						eval $GRAPH_PNG --title \"$SUBREPORT $SUB_WORKLOAD $ADDRSPACE\" --sub-heading $SUB_WORKLOAD-$ADDRSPACE --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$SUB_WORKLOAD-$ADDRSPACE
						plain graph-$SUBREPORT-$SUB_WORKLOAD-$ADDRSPACE
				done
				echo "</tr>"
			done
			;;
		wptlbflush)
			for CLIENT in `$COMPARE_BARE_CMD | grep ^Min | awk '{print $2}' | sed -e 's/.*-//' | sort -n | uniq`; do
				echo "<tr>"
				eval $GRAPH_PNG -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT --with-smooth
				eval $GRAPH_PNG -b $SUBREPORT --title \"$SUBREPORT $CLIENT procs sorted\" --sub-heading procs-$CLIENT --output $OUTPUT_DIRECTORY/graph-${SUBREPORT}-$CLIENT-sorted --sort-samples-reverse
				smoothover graph-$SUBREPORT-$CLIENT
				plain graph-$SUBREPORT-$CLIENT-sorted
				echo "</tr>"
			done
			;;
		xfsrepair)
			;;
		*)
			eval $GRAPH_PNG $GRAPH_EXTRA --title \"$SUBREPORT\" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT.png ]; then
				if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-smooth.png ]; then
					smoothover graph-$SUBREPORT
				else
					plain graph-$SUBREPORT
				fi
			else
				echo "<tr><td>No graph representation</td></tr>"
			fi
		esac
		echo "</table>"

		if [ "$IOSTAT_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			for DEVICE in `grep ^Mean /tmp/iostat-$$ | awk '{print $2}' | awk -F - '{print $1}' | sort | uniq`; do
				echo "<table class=\"resultsGraphs\">"
				echo "<tr>"
				for PARAM in avgqusz await r_await w_await; do
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM --with-smooth
					smoothover graph-$SUBREPORT-$DEVICE-$PARAM
				done
				echo "</tr>"
				echo "<tr>"
				for PARAM in avgrqsz rrqm wrqm; do
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM --with-smooth
					smoothover graph-$SUBREPORT-$DEVICE-$PARAM
				done
				echo "</tr>"
				echo "<tr>"
				for PARAM in rkbs wkbs totalkbs; do
					eval $GRAPH_PNG --title \"$DEVICE $PARAM\"   --print-monitor iostat --sub-heading $DEVICE-$PARAM --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$DEVICE-$PARAM --with-smooth
					smoothover graph-$SUBREPORT-$DEVICE-$PARAM
				done
				echo "</tr>"

				echo "</table>"
			done
		fi
		rm -f /tmp/iostat-$$

		if have_monitor_results bdi $KERNEL_BASE; then
			echo "<table class=\"resultsGraphs\">"
			eval $GRAPH_PNG --title \"BdiWriteback\"      --print-monitor bdi --sub-heading BdiWriteback      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-bdiwriteback
			eval $GRAPH_PNG --title \"BdiWriteBandwidth\" --print-monitor bdi --sub-heading BdiWriteBandwidth --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-bdiwritebandwidth
			eval $GRAPH_PNG --title \"BdiDirtied\"        --print-monitor bdi --sub-heading BdiDirtied        --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-bdidirtied
			eval $GRAPH_PNG --title \"BdiWritten\"        --print-monitor bdi --sub-heading BdiWritten        --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-bdiwritten

			echo "<tr>"
			plain graph-$SUBREPORT-bdiwriteback
			plain graph-$SUBREPORT-bdiwritebandwidth
			echo "</tr><tr>"
			plain graph-$SUBREPORT-bdidirtied
			plain graph-$SUBREPORT-bdiwritten
			echo "</tr>"
			echo "</table>"
		fi

		if [ "$KCACHE_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --yrange 0:$((ALLOCS+FREES)) --title \"Kcache allocations\"   --print-monitor kcacheslabs --sub-heading allocs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-kcache-allocs
			eval $GRAPH_PNG --yrange 0:$((ALLOCS+FREES)) --title \"Kcache frees\"         --print-monitor kcacheslabs --sub-heading frees  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-kcache-frees
			echo "<table class=\"resultsGraphs\">"
			echo "<tr>"
			plain graph-$SUBREPORT-kcache-allocs
			plain graph-$SUBREPORT-kcache-frees
			echo "</tr>"
			echo "</table>"
		fi
		rm -f /tmp/kcache.$$

		if [ "$FTRACE_ALLOCLATENCY_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"Direct reclaim allocation stalls\"   --print-monitor ftraceallocstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-alloc-stalls
			eval $GRAPH_PNG --title \"Direct reclaim allocation stalls logY\"   --print-monitor ftraceallocstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-alloc-stalls-logY --logY
			echo "<tr>"
			plain graph-$SUBREPORT-ftrace-alloc-stalls
			plain graph-$SUBREPORT-ftrace-alloc-stalls-logY
			echo "</tr>"
		fi

		if [ "$FTRACE_SHRINKERLATENCY_GRAPH" = "yes" -a "$FORMAT" = "html" -a -d "$OUTPUT_DIRECTORY" ]; then
			eval $GRAPH_PNG --title \"Slab shrinker stall kswapd\"       --print-monitor ftraceshrinkerstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd
			eval $GRAPH_PNG --title \"Slab shrinker stall not kswapd\"   --print-monitor ftraceshrinkerstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd

			eval $GRAPH_PNG --title \"Slab shrinker stall kswapd logY\"       --print-monitor ftraceshrinkerstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-kswapd-logY --logY
			eval $GRAPH_PNG --title \"Slab shrinker stall not kswapd logY\"   --print-monitor ftraceshrinkerstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-shrinker-stalls-no-kswapd-logY --logY

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
			eval $GRAPH_PNG --title \"Compaction stalls khugepaged\"                          --print-monitor ftracecompactstall --sub-heading khugepaged                     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-khugepaged
			eval $GRAPH_PNG --title \"Compaction stalls kswapd or kcompactd\"                 --print-monitor ftracecompactstall --sub-heading kswapd-kcompactd               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd
			eval $GRAPH_PNG --title \"Compaction stalls not khugepaged, kswapd or kcompactd\" --print-monitor ftracecompactstall --sub-heading no-kswapd-kcompactd-khugepaged --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged
			eval $GRAPH_PNG --title \"Compaction stalls khugepaged\"                          --print-monitor ftracecompactstall --sub-heading khugepaged                     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-khugepaged-logY --logY
			eval $GRAPH_PNG --title \"Compaction stalls kswapd or kcompactd logY\"                 --print-monitor ftracecompactstall --sub-heading kswapd-kcompactd               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-kswapd-kcompactd-logY --logY
			eval $GRAPH_PNG --title \"Compaction stalls not khugepaged, kswapd or kcompactd logY\" --print-monitor ftracecompactstall --sub-heading no-kswapd-kcompactd-khugepaged --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-compact-stalls-no-kswapd-kcompactd-khugepaged-logY --logY

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
			eval $GRAPH_PNG --title \"wait_iff_congested stall kswapd\"       --print-monitor ftracewaitiffcongestedstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd
			eval $GRAPH_PNG --title \"wait_iff_congested stall not kswapd\"   --print-monitor ftracewaitiffcongestedstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd

			eval $GRAPH_PNG --title \"wait_iff_congested stall kswapd logY\"       --print-monitor ftracewaitiffcongestedstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-kswapd-logY --logY
			eval $GRAPH_PNG --title \"wait_iff_congested stall not kswapd logY\"   --print-monitor ftracewaitiffcongestedstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-waitiffcongested-stalls-no-kswapd-logY --logY

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
			eval $GRAPH_PNG --title \"congestion_wait stall kswapd\"       --print-monitor ftracecongestionwaitstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd
			eval $GRAPH_PNG --title \"congestion_wait stall not kswapd\"   --print-monitor ftracecongestionwaitstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd

			eval $GRAPH_PNG --title \"congestion_wait stall kswapd logY\"       --print-monitor ftracecongestionwaitstall --sub-heading kswapd    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-kswapd-logY --logY
			eval $GRAPH_PNG --title \"congestion_wait stall not kswapd logY\"   --print-monitor ftracecongestionwaitstall --sub-heading no-kswapd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-congestionwait-stalls-no-kswapd-logY --logY

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
			eval $GRAPH_PNG --title \"Balance Dirty Pages stalls : worst-case not actual and assumes HZ=250\"   --print-monitor ftracebalancedirtypagesstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-balancedirtypages-stalls
			eval $GRAPH_PNG --title \"Balance Dirty Pages stalls : worst-case not actual and assumes HZ=250 logY\"   --print-monitor ftracebalancedirtypagesstall --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-ftrace-balancedirtypages-stalls-logY --logY
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
			echo "</table>"
			echo "<table class=\"monitorGraphs\">"
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
					for PROCESS in `awk '{print $1}' /tmp/iotop-mmtests-$$/$KERNEL-data | sort | uniq`; do
						PRETTY=`echo $PROCESS | sed -e 's/\[//g' -e 's/\]//g' -e 's/\.\///' -e 's/\//__/' -e 's/(.*)//'`
						grep -F "$PROCESS " /tmp/iotop-mmtests-$$/$KERNEL-data | awk '{print $3" "$4}' > /tmp/iotop-mmtests-$$/$PRETTY
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
						eval plot --xrange 0: --yrange 0:$MAX --title \"$KERNEL process $OP activity\" --plottype points --titles \"$TITLE_LIST\" --format png         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-${KERNEL}.png --medium $PROCESS_LIST
						plain graph-$SUBREPORT-iotop-$OP-$KERNEL
					else
						echo "<td><center>No IO activity $KERNEL $OP</center></td>"
					fi

					rm -rf /tmp/iotop-mmtests-$$/*
				done
				echo "</tr>"
				echo "</table>"
				echo "<table class=\"monitorGraphs\">"
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
						eval plot --logY --title \"$KERNEL thread-$CALC $OP\" --plottype points --titles \"$TITLE_LIST\" --format png  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC $PLOT_LIST
						eval plot        --title \"$KERNEL thread-$CALC $OP\" --plottype lines  --titles \"$TITLE_LIST\" --format png  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-iotop-$OP-$CALC-smooth --smooth bezier $PLOT_LIST 
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
			EVENTS=`$EXTRACT_CMD -n $KERNEL_BASE --print-monitor turbostat | awk '{print $1}' | uniq`
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
				eval $GRAPH_PNG --title \"$EVENT\"   $RANGE_CMD --print-monitor turbostat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-turbostat-$EVENT_FILENAME --with-smooth
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
			EVENTS=`$EXTRACT_CMD -n $KERNEL_BASE --print-monitor perf-time-stat | awk '{print $1}' | uniq`
			COUNT=-1
			for EVENT in $EVENTS; do
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				eval $GRAPH_PNG --title \"$EVENT\"   --print-monitor perf-time-stat --sub-heading $EVENT --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-perf-time-stat-$EVENT --with-smooth
				smoothover graph-$SUBREPORT-perf-time-stat-$EVENT
				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi
		fi

		if have_monitor_results proc-schedstat $KERNEL_BASE; then
			eval $GRAPH_PNG --yrange -5:105 --title \"SIS Efficiency\" --print-monitor procschedstat --sub-heading mmtests_sis_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-sisefficiency
			eval $GRAPH_PNG --yrange -5:105 --title \"SIS Domain Efficiency\" --print-monitor procschedstat --sub-heading mmtests_sis_domain_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-sisdomainefficiency
			eval $GRAPH_PNG --yrange -5:105 --title \"SIS Success Rate\" --print-monitor procschedstat --sub-heading mmtests_sis_success --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-success
			eval $GRAPH_PNG --yrange -5:105 --title \"SIS Fast Success Rate\" --print-monitor procschedstat --sub-heading mmtests_sis_fast_success --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-fastsuccess
			eval $GRAPH_PNG --logY --title \"SIS Scanned\" --print-monitor procschedstat --sub-heading sis_scanned --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-scanned
			eval $GRAPH_PNG --logY --title \"SIS Domain Scanned\" --print-monitor procschedstat --sub-heading mmtests_sis_domain_scanned --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-domainscanned
			eval $GRAPH_PNG --title \"TTWU Count\" --print-monitor procschedstat --sub-heading ttwu_count --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-ttwucount
			eval $GRAPH_PNG --title \"TTWU Local\" --print-monitor procschedstat --sub-heading ttwu_local --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-ttwulocal
			eval $GRAPH_PNG --logY --title \"SIS Failure\" --print-monitor procschedstat --sub-heading sis_failed --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-sisfailure
			eval $GRAPH_PNG --yrange -5:105 --title \"SIS Recent Success Rate\" --print-monitor procschedstat --sub-heading mmtests_sis_recent_success --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-recentsuccess
			eval $GRAPH_PNG --yrange -5:105 --title \"SIS Recent Success Rate\" --print-monitor procschedstat --sub-heading mmtests_sis_recent_success --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-recentsuccess --with-smooth

			eval $GRAPH_PNG --yrange -5:105 --title \"SIS Core Efficiency\" --print-monitor procschedstat --sub-heading mmtests_sis_core_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-siscoreefficiency
			eval $GRAPH_PNG --logY --title \"SIS Core Search\" --print-monitor procschedstat --sub-heading sis_core_search --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-siscoresearch
			eval $GRAPH_PNG --logY --title \"SIS Core Hit\" --print-monitor procschedstat --sub-heading mmtests_sis_core_hit --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-siscorehit
			eval $GRAPH_PNG --logY --title \"SIS Core Miss\" --print-monitor procschedstat --sub-heading sis_core_miss --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-schedstat-siscoremiss
			echo "<tr>"
			plain graph-$SUBREPORT-schedstat-sisefficiency
			plain graph-$SUBREPORT-schedstat-sisdomainefficiency
			echo "</tr><tr>"
			plain graph-$SUBREPORT-schedstat-success
			plain graph-$SUBREPORT-schedstat-fastsuccess
			echo "</tr><tr>"
			plain graph-$SUBREPORT-schedstat-scanned
			plain graph-$SUBREPORT-schedstat-domainscanned
			echo "</tr><tr>"
			plain graph-$SUBREPORT-schedstat-siscorehit
			plain graph-$SUBREPORT-schedstat-siscoremiss
			echo "</tr><tr>"
			plain graph-$SUBREPORT-schedstat-siscoresearch
			plain graph-$SUBREPORT-schedstat-siscoreefficiency
			echo "</tr><tr>"
			plain graph-$SUBREPORT-schedstat-ttwucount
			plain graph-$SUBREPORT-schedstat-ttwulocal
			echo "</tr><tr>"
			plain graph-$SUBREPORT-schedstat-sisfailure
			smoothover graph-$SUBREPORT-schedstat-recentsuccess
			echo "</tr>"
		fi

		if have_monitor_results mpstat $KERNEL_BASE; then
			echo "<tr>"
			for NID in `zgrep cpus: $KERNEL_BASE/iter-0/numactl.txt.gz | awk '{print $2}'`; do
				eval $GRAPH_PNG --title \"Node $NID Total CPU Usage\" --print-monitor mpstat --sub-heading node-$NID --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-node-$NID-cpuusage
				plain graph-$SUBREPORT-node-$NID-cpuusage
			done
			echo "</tr>"
		fi
		if have_monitor_results vmstat $KERNEL_BASE; then
			eval $GRAPH_PNG --title \"User CPU Usage\"   --print-monitor vmstat --sub-heading us --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-us --with-smooth
			eval $GRAPH_PNG --title \"System CPU Usage\" --print-monitor vmstat --sub-heading sy --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-sy --with-smooth
			eval $GRAPH_PNG --title \"Wait CPU Usage\"   --print-monitor vmstat --sub-heading wa --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-wa --with-smooth 2> /dev/null

			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-us
			smoothover graph-$SUBREPORT-vmstat-sy
			smoothover graph-$SUBREPORT-vmstat-wa
			echo "</tr>"

			eval $GRAPH_PNG --title \"Runnable Processes\"   --print-monitor vmstat --sub-heading r --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-r --with-smooth
			eval $GRAPH_PNG --title \"Blocked Processes\"    --print-monitor vmstat --sub-heading b --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-b --with-smooth
			eval $GRAPH_PNG --title \"Total CPU Usage\"       --print-monitor vmstat --sub-heading totalcpu --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-totalcpu --with-smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-r
			smoothover graph-$SUBREPORT-vmstat-b
			smoothover graph-$SUBREPORT-vmstat-totalcpu
			echo "</tr>"

			eval $GRAPH_PNG --title \"User/Kernel CPU Ratio\" --print-monitor vmstat --sub-heading ussy     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-ussy --with-smooth

			if have_monitor_results proc-vmstat $KERNEL_BASE; then
				eval $GRAPH_PNG --title \"Minor Faults\" --logY   --print-monitor proc-vmstat --sub-heading mmtests_minor_faults --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults --with-smooth
				eval $GRAPH_PNG --title \"Major Faults\" --logY   --print-monitor proc-vmstat --sub-heading pgmajfault --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-majorfaults --with-smooth
			fi
			echo "<tr>"
			smoothover graph-$SUBREPORT-vmstat-ussy
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-minorfaults.png ]; then
				smoothover graph-$SUBREPORT-proc-vmstat-minorfaults
			fi
			if [ -e $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-majorfaults.png ]; then
				MAJFAULTS=`$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading pgmajfault | awk '{print $2}' | grep -v Nan | max`
				if [ "$MAJFAULTS" = "" ]; then
					MAJFAULTS=0
				fi
				if [ $MAJFAULTS -gt 0 ]; then
					smoothover graph-$SUBREPORT-proc-vmstat-majorfaults
				else
					echo "<td><center>No major page faults</center></td>"
				fi
			fi
			echo "</tr>"
		fi

		if have_monitor_results vmstat $KERNEL_BASE; then
			eval $GRAPH_PNG --title \"Free Memory\"      --print-monitor vmstat --sub-heading free --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-free
			eval $GRAPH_PNG --title \"Context Switches\" --print-monitor vmstat --sub-heading cs --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-cs --with-smooth
			eval $GRAPH_PNG --title \"Interrupts\"       --print-monitor vmstat --sub-heading in --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-in --with-smooth

			echo "<tr>"
			plain graph-$SUBREPORT-vmstat-free
			smoothover graph-$SUBREPORT-vmstat-cs
			smoothover graph-$SUBREPORT-vmstat-in
			echo "</tr>"
		fi
		if have_monitor_results proc-vmstat $KERNEL_BASE; then
			eval $GRAPH_PNG --title \"Dirty Pages\"    --print-monitor proc-vmstat --sub-heading nr_dirty --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty --with-smooth 2> /dev/null
			eval $GRAPH_PNG --title \"Writeback Pages\"    --print-monitor proc-vmstat --sub-heading nr_writeback --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_writeback --with-smooth 2> /dev/null
			eval $GRAPH_PNG --title \"Dirty Background Threshold\"    --print-monitor proc-vmstat --sub-heading nr_dirty_background_threshold --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nr_dirty_background_threshold --with-smooth 2> /dev/null
			eval $GRAPH_PNG --title \"THPages\"    --print-monitor proc-vmstat --sub-heading nr_anon_transparent_hugepages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-thp --with-smooth 2> /dev/null
			eval $GRAPH_PNG --title \"Anon Pages\" --print-monitor proc-vmstat --sub-heading mmtests_total_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-anon --with-smooth
			eval $GRAPH_PNG --title \"File Pages\" --print-monitor proc-vmstat --sub-heading nr_file_pages --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-file --with-smooth
			eval $GRAPH_PNG --title \"Slab Unreclaimable pages\"    --print-monitor proc-vmstat --sub-heading nr_slab_unreclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-unreclaimable --with-smooth
			eval $GRAPH_PNG --title \"Slab Reclaimable pages\"    --print-monitor proc-vmstat --sub-heading nr_slab_reclaimable --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab-reclaimable --with-smooth
			eval $GRAPH_PNG --title \"Total slab pages\"    --print-monitor proc-vmstat --sub-heading mmtests_total_slab --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slab --with-smooth

			eval $GRAPH_PNG --title \"Ratio Slab/FileCache\" --print-monitor proc-vmstat --sub-heading mmtests_ratio_slab_filecache --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-ratio-slab-filecache
			eval $GRAPH_PNG --title \"Ratio Slab/PageCache\" --print-monitor proc-vmstat --sub-heading mmtests_ratio_slab_pagecache --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-ratio-slab-pagecache
			eval $GRAPH_PNG --title \"PFree Memory\"      --print-monitor vmstat --sub-heading pfree --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-pfree

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
			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-ratio-slab-filecache
			smoothover graph-$SUBREPORT-proc-vmstat-ratio-slab-pagecache
			smoothover graph-$SUBREPORT-vmstat-pfree
			echo "</tr>"


                        eval $GRAPH_PNG --title \"Total Sector IO\" --print-monitor proc-vmstat --sub-heading pgpgtotal  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgptotal --with-smooth
			eval $GRAPH_PNG --title \"Sector Reads\"      --print-monitor proc-vmstat --sub-heading pgpgin     --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpin --with-smooth
			eval $GRAPH_PNG --title \"Sector Writes\"     --print-monitor proc-vmstat --sub-heading pgpgout    --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgpout --with-smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-pgptotal
			smoothover graph-$SUBREPORT-proc-vmstat-pgpin
			smoothover graph-$SUBREPORT-proc-vmstat-pgpout
			echo "</tr>"

			if [ "$SWAP_GRAPH" = "yes" ]; then
				eval $GRAPH_PNG --title \"Swap Usage\" --print-monitor vmstat --sub-heading swpd --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-swpd
				eval $GRAPH_PNG --title \"Swap Ins\"   --print-monitor vmstat --sub-heading si   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-si --with-smooth
				eval $GRAPH_PNG --title \"Swap Outs\"  --print-monitor vmstat --sub-heading so   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-vmstat-so --with-smooth

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
				$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan | awk '{print $NF}' | grep -q -v "^0"
				if [ $? -eq 0 ]; then
					KSWAPD_ACTIVITY=yes
				fi
				$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading mmtests_direct_scan | awk '{print $NF}' | grep -q -v "^0"
				if [ $? -eq 0 ]; then
					DIRECT_ACTIVITY=yes
				fi
				$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading slabs_scanned | awk '{print $NF}' | grep -q -v "^0"
				if [ $? -eq 0 ]; then
					SLAB_ACTIVITY=yes

					$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading kswapd_inodesteal | awk '{print $NF}' | grep -q -v "^0"
					if [ $? -eq 0 ]; then
						KSWAPD_INODE_STEAL_ACTIVITY=yes
					fi
					$EXTRACT_CMD -n $KERNEL --print-monitor proc-vmstat --sub-heading pginodesteal | awk '{print $NF}' | grep -q -v "^0"
					if [ $? -eq 0 ]; then
						DIRECT_INODE_STEAL_ACTIVITY=yes
					fi
				fi

			done
		fi
		if [ "$DIRECT_ACTIVITY" = "yes" ]; then
			eval $GRAPH_PNG --title \"Direct Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_direct_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-scan --with-smooth
			eval $GRAPH_PNG --title \"Direct Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_direct_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-steal --with-smooth
			eval $GRAPH_PNG --title \"Direct Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_direct_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-efficiency --with-smooth 2> /dev/null
			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-direct-scan
			smoothover graph-$SUBREPORT-proc-vmstat-direct-steal
			smoothover graph-$SUBREPORT-proc-vmstat-direct-efficiency
			echo "</tr>"
		fi

		if [ "$KSWAPD_ACTIVITY" = "yes" ]; then
			eval $GRAPH_PNG --title \"KSwapd Reclaim Scan\"  --print-monitor proc-vmstat --sub-heading mmtests_kswapd_scan  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-scan  --with-smooth
			eval $GRAPH_PNG --title \"KSwapd Reclaim Steal\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_steal --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-steal --with-smooth
			eval $GRAPH_PNG --title \"KSwapd Reclaim Efficiency\" --print-monitor proc-vmstat --sub-heading mmtests_kswapd_efficiency --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-efficiency --with-smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-kswapd-scan
			smoothover graph-$SUBREPORT-proc-vmstat-kswapd-steal
			smoothover graph-$SUBREPORT-proc-vmstat-kswapd-efficiency
			echo "</tr>"

			eval $GRAPH_PNG --title \"KSwapd CPU Usage\"    --print-monitor top                                                 --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-top-kswapd --with-smooth
			eval $GRAPH_PNG --title \"File Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_file --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-file-writes --with-smooth
			eval $GRAPH_PNG --title \"Anon Reclaim Writes\" --print-monitor proc-vmstat --sub-heading mmtests_vmscan_write_anon --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-reclaim-anon-writes --with-smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-top-kswapd
			smoothover graph-$SUBREPORT-proc-vmstat-reclaim-file-writes
			smoothover graph-$SUBREPORT-proc-vmstat-reclaim-anon-writes
			echo "</tr>"
		fi

		if [ "$SLAB_ACTIVITY" = "yes" ]; then
			eval $GRAPH_PNG --title \"Slabs scanned\"       --print-monitor proc-vmstat --sub-heading slabs_scanned      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-slabs-scanned
			if [ "$KSWAPD_INODE_STEAL_ACTIVITY" = "yes" ]; then
				eval $GRAPH_PNG --title \"Kswapd inode steal\"  --print-monitor proc-vmstat --sub-heading kswapd_inodesteal  --logY --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-kswapd-inode-steal
			fi
			if [ "$DIRECT_INODE_STEAL_ACTIVITY" = "yes" ]; then
				eval $GRAPH_PNG --title \"Direct inode steal\"  --print-monitor proc-vmstat --sub-heading pginodesteal       --logY --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-direct-inode-steal
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

		if have_monitor_results proc-vmstat $KERNEL_BASE "^compact_isolated [1-9]"; then
			eval $GRAPH_PNG --title \"Compaction pages isolated\"  --print-monitor proc-vmstat --sub-heading compact_isolated                        --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_isolated --with-smooth
			eval $GRAPH_PNG --title \"Compaction migrate scanned\" --print-monitor proc-vmstat --sub-heading compact_migrate_scanned        --logY   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_migrate_scanned --with-smooth
			eval $GRAPH_PNG --title \"Compaction free scanned\"    --print-monitor proc-vmstat --sub-heading compact_free_scanned           --logY   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_free_scanned --with-smooth

			eval $GRAPH_PNG --title \"Kcompactd wake\"            --print-monitor proc-vmstat --sub-heading compact_daemon_wake                      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_daemon_wake --with-smooth
			eval $GRAPH_PNG --title \"Kcompactd migrate scanned\" --print-monitor proc-vmstat --sub-heading compact_daemon_migrate_scanned  --logY   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_daemon_migrate_scanned --with-smooth
			eval $GRAPH_PNG --title \"Kcompactd free scanned\"    --print-monitor proc-vmstat --sub-heading compact_daemon_free_scanned     --logY   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_daemon_free_scanned --with-smooth

			eval $GRAPH_PNG --title \"Compaction stall\"          --print-monitor proc-vmstat --sub-heading compact_stall                            --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-compact_stall --with-smooth
			eval $GRAPH_PNG --title \"Pages successful migrate\"  --print-monitor proc-vmstat --sub-heading pgmigrate_success                        --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_success --with-smooth
			eval $GRAPH_PNG --title \"Pages failed migrate\"      --print-monitor proc-vmstat --sub-heading pgmigrate_fail                           --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-pgmigrate_failure --with-smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-compact_isolated
			smoothover graph-$SUBREPORT-proc-vmstat-compact_migrate_scanned
			smoothover graph-$SUBREPORT-proc-vmstat-compact_free_scanned
			echo "</tr>"

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-compact_daemon_wake
			smoothover graph-$SUBREPORT-proc-vmstat-compact_daemon_migrate_scanned
			smoothover graph-$SUBREPORT-proc-vmstat-compact_daemon_free_scanned
			echo "</tr>"

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-compact_stall
			smoothover graph-$SUBREPORT-proc-vmstat-pgmigrate_success
			smoothover graph-$SUBREPORT-proc-vmstat-pgmigrate_failure
			echo "</tr>"
		fi

		if have_monitor_results proc-vmstat $KERNEL_BASE "^numa_hint_faults [1-9]"; then
			eval $GRAPH_PNG --title \"NUMA base-page range updates\"       --print-monitor proc-vmstat     --sub-heading numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-size-updates --with-smooth
			eval $GRAPH_PNG --title \"NUMA PTE Updates\"       --print-monitor proc-vmstat     --sub-heading mmtests_numa_pte_updates      --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-pte-updates --with-smooth
			eval $GRAPH_PNG --title \"NUMA Huge PMD Updates\"  --print-monitor proc-vmstat     --sub-heading mmtests_numa_pmd_updates --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-huge-pmd-updates --with-smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-numa-pte-size-updates
			smoothover graph-$SUBREPORT-proc-vmstat-numa-pte-updates
			smoothover graph-$SUBREPORT-proc-vmstat-numa-huge-pmd-updates
			## smoothover graph-$SUBREPORT-proc-vmstat-numa_pages_migrated
			echo "</tr>"

			eval $GRAPH_PNG --title \"NUMA Hints Local\"     --print-monitor proc-vmstat --sub-heading numa_hint_faults_local  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local --with-smooth
			eval $GRAPH_PNG --title \"NUMA Hints Remote\"    --print-monitor proc-vmstat --sub-heading mmtests_hint_faults_remote --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-remote --with-smooth
			eval $GRAPH_PNG --title \"NUMA Hints Local Pct\" --print-monitor proc-vmstat --sub-heading numa_hint_faults_local_pct --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints-local-pct --with-smooth

			echo "<tr>"
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints-local
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints-remote
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints-local-pct
			echo "</tr>"

			echo "<tr>"
			eval $GRAPH_PNG --title \"NUMA Migrations\"        --print-monitor proc-vmstat     --sub-heading numa_pages_migrated   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa_pages_migrated --with-smooth
			smoothover graph-$SUBREPORT-proc-vmstat-numa_pages_migrated
			echo "</tr>"

			echo "<tr>"
			eval $GRAPH_PNG --title \"NUMA Hint Faults\"     --print-monitor proc-vmstat --sub-heading numa_hint_faults  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hints --with-smooth
			eval $GRAPH_PNG --logY --title \"Normal Non-NUMA minor faults\"     --print-monitor proc-vmstat --sub-heading mmtests_normal_minor_faults  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-nonnuma-minor-faults --with-smooth
			eval $GRAPH_PNG --title \"NUMA Hint Percentage\"     --print-monitor proc-vmstat --sub-heading mmtests_faults_pct_numa  --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-vmstat-numa-hint-pct --with-smooth

			smoothover graph-$SUBREPORT-proc-vmstat-numa-hints
			smoothover graph-$SUBREPORT-proc-vmstat-nonnuma-minor-faults
			smoothover graph-$SUBREPORT-proc-vmstat-numa-hint-pct
			echo "</tr>"
		fi

		if have_monitor_results numa-meminfo $KERNEL_BASE; then
			if [ `zgrep ^Node */numa-meminfo-* | awk '{print $2}' | sort | uniq | wc -l` -gt 1 ]; then
				eval $GRAPH_PNG --title \"NUMA Memory Balance\" --print-monitor Numanodeusage   --sub-heading MemoryBalance         --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-memory-balance --with-smooth
				eval $GRAPH_PNG --title \"NUMA Convergence\"    --print-monitor Numaconvergence                                   --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numa-convergence
				echo "<tr>"
				smoothover graph-$SUBREPORT-numa-memory-balance
				plain graph-$SUBREPORT-numa-convergence
				echo "</tr>"
			fi
		fi

		if have_monitor_results ftrace $KERNEL_BASE "mm_migrate_misplaced_pages"; then
			PLOT_TITLES=
			for NAME in `echo $KERNEL_LIST | sed -e 's/,/ /g'`; do
				$EXTRACT_CMD -n $NAME --print-monitor Ftracenumatraffic > /tmp/mmtests-numatraffic-$$-$NAME
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
						plot --yrange 0:$MAX_MIGRATION --title "NUMA balance page migrate from node $NID" --titles "$PLOT_TITLES" --plottype $PLOTTYPE --format png                               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numab-migrate-from-$NID-${NAME} /tmp/mmtests-numatraffic-plot-$$-$NAME
						plot --yrange 0:$MAX_MIGRATION --title "NUMA balance page migrate from node $NID" --titles "$PLOT_TITLES" --plottype $PLOTTYPE --format "postscript color solid" --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numab-migrate-from-$NID-${NAME}.ps  /tmp/mmtests-numatraffic-plot-$$-$NAME
						plain graph-$SUBREPORT-numab-migrate-from-$NID-${NAME}
					done
					echo "</tr>"
					echo "<tr>"
					for NID in `seq 0 $MAX_NID`; do
						grep "to-$NID " /tmp/mmtests-numatraffic-$$-$NAME | awk '{print $1" "$3}' > /tmp/mmtests-numatraffic-plot-$$-$NAME
						plot --yrange 0:$MAX_MIGRATION --title "NUMA balance page migrate to node $NID" --titles "$PLOT_TITLES" --plottype $PLOTTYPE --format png                               --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-numab-migrate-to-$NID-${NAME} /tmp/mmtests-numatraffic-plot-$$-$NAME
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
				eval $GRAPH_PNG --title \"$INTERFACE Received Bytes\"      --print-monitor proc-net-dev --sub-heading $INTERFACE-rbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rbytes --with-smooth
				eval $GRAPH_PNG --title \"$INTERFACE Received Packets\"    --print-monitor proc-net-dev --sub-heading $INTERFACE-rpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-rpackets --with-smooth
				eval $GRAPH_PNG --title \"$INTERFACE Transmitted Bytes\"   --print-monitor proc-net-dev --sub-heading $INTERFACE-tbytes --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tbytes --with-smooth
				eval $GRAPH_PNG --title \"$INTERFACE Transmitted Packets\" --print-monitor proc-net-dev --sub-heading $INTERFACE-tpackets --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-net-dev-$INTERFACE-tpackets --with-smooth

				echo "<tr>"
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-rbytes
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-rpackets
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-tbytes
				smoothover graph-$SUBREPORT-proc-net-dev-$INTERFACE-tpackets
				echo "</tr>"
			done
		fi

		echo "</table>"

		if have_monitor_results proc-interrupts $KERNEL_BASE; then
			SOURCES=`$EXTRACT_CMD -n $KERNEL --print-monitor proc-interrupts | awk '{print $1}' | sort | uniq | grep -v -- -edge- `
			echo "<table>"
			COUNT=-1
			for HEADING in $SOURCES; do
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				eval $GRAPH_PNG --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING --with-smooth
				smoothover graph-$SUBREPORT-proc-interrupts-$HEADING
				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi

			for HEADING in $SOURCES; do
				COUNT=$((COUNT+1))
				if [ $((COUNT%3)) -eq 0 ]; then
					echo "<tr>"
				fi
				eval $GRAPH_PNG --title \"$HEADING\" --print-monitor proc-interrupts --sub-heading $HEADING --output $OUTPUT_DIRECTORY/graph-$SUBREPORT-proc-interrupts-$HEADING-logY --logY
				plain graph-$SUBREPORT-proc-interrupts-$HEADING-logY
				if [ $((COUNT%3)) -eq 2 ]; then
					echo "</tr>"
				fi
			done
			if [ $((COUNT%3)) -ne 2 ]; then
				echo "</tr>"
			fi
			echo "</table>"
		fi

		if have_monitor_results mpstat $KERNEL_BASE; then
			echo "<table>"
			echo "<tr>"
			for KERNEL in $KERNEL_LIST_ITER; do
				rm -f $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat.png
				visualise-log.pl -b gd							\
					--output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat.png	\
					-t $KERNEL/iter-0/cpu-topology-mmtests.txt.gz			\
					-l mpstat							\
					-i $KERNEL/iter-0/mpstat-$SUBREPORT.gz				\
					-a $KERNEL/iter-0/tests-activity
				montage -title "$KERNEL" $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat.png -geometry +5+5 $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat.png
				plain graph-$SUBREPORT-$KERNEL-mpstat 400
			done
			echo "</tr>"
			echo "<tr>"
			for KERNEL in $KERNEL_LIST_ITER; do
				rm -f $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat-llc.png
				visualise-log.pl -b gd							\
					-c llc								\
					--output $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat-llc.png	\
					-t $KERNEL/iter-0/cpu-topology-mmtests.txt.gz			\
					-l mpstat							\
					-i $KERNEL/iter-0/mpstat-$SUBREPORT.gz				\
					-a $KERNEL/iter-0/tests-activity
				montage -title "$KERNEL" $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat-llc.png -geometry +5+5 $OUTPUT_DIRECTORY/graph-$SUBREPORT-$KERNEL-mpstat-llc.png
				plain graph-$SUBREPORT-$KERNEL-mpstat-llc 400
			done
			echo "</tr>"

			echo "</table>"
		fi
	fi
done
cat $SCRIPTDIR/shellpacks/common-footer-$FORMAT 2> /dev/null

if [ "$OUTPUT_DIRECTORY" != "" ]; then
	echo -n $REPORT_FINGERPRINT > $OUTPUT_DIRECTORY/report.md5
fi

exit 0

: <<=cut
=pod

=head1 NAME

compare-kernels.sh - Compare results between benchmarking runs

=head1 SYNOPSIS

compare-kernels.sh B<[options]>

 Options:
  --baseline <testname>		Baseline test name, default is time ordered
  --compare  "<test> <test>"	Comparison test names, space separated
  --exclude  "<test> <test>"	Exclude test names
  --auto-detect			Attempt to automatically highlight significant differences
  --sort-version		Assume kernel versions for test names and attempt to sort
  --format html			Generate a HTML format of the report
  --output-dir			Output directory for HTML report
  -h, --help			Print this help

=head1 DESCRIPTION

B<compare-kernels.sh> despite its name compares an arbitrary number of
benchmarking runs. Historically, the only use case was kernel versions
hence the name but in practice, anything can be compared -- machines,
userspace packages, benchmark versions, tuning parameters etc.

The default output mode is text in which case only basic reports will
be generated. If HTML reports are generated then graphs of both the
benchmark itself and enabled monitors will also be created.

Significance testing is optional and may report false positives or
false negatives so treat it as a guideline only.

Note that it is assumed that the log directory consists of results from
the same configuration file. If there is a mix of configurations and
benchmarks used then the comparison script will get confused and the
output will be unusable.

=head1 EXAMPLE

$ cd work/log

$ ../../compare-kernels.sh

$ mkdir /tmp/report/

$ ../../compare-kernels.sh --format html --output-dir /tmp/report > /tmp/report/index.html

=head1 AUTHOR

B<Mel Gorman <mgorman@techsingularity.net>>

=head1 REPORTING BUGS

Report bugs to the author.
