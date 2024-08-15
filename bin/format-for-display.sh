#!/bin/bash
set ${MMTESTS_SH_DEBUG:-+x}

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
export PATH=$SCRIPTDIR:$PATH
. $SCRIPTDIR/../shellpacks/common.sh
. $SCRIPTDIR/../shellpacks/common-config.sh
. $SCRIPTDIR/../config

KERNEL_BASE=
KERNEL_COMPARE=

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
	--webroot)
		REPORTROOT="$2"
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
	--top)
		TOPNUM="$2"
		shift 2
		;;
	--topout)
		TOPOUT="$2"
		shift 2
		;;
	--toplatest)
		TOPLATEST=yes
		shift
		;;
	--table-id)
		TABLEID="$2"
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
	LIST_SORTED=`echo $LIST_SORT | sed -e 's/,/\n/g' | sort -t . -k1,1 -k2,2 -k3,3 -n`
	LIST_SORTED_STRIPPED=

	# Strip so only the latest stable major versions are included
	declare -a LIST_ARRAY
	LIST_ARRAY=(`echo ${LIST_SORTED}`);
	NR_ELEMENTS=${#LIST_ARRAY[@]}
	for INDEX in ${!LIST_ARRAY[@]}; do
		KERNEL=${LIST_ARRAY[$INDEX]}
		CURRENT_MAJOR=`echo $KERNEL | awk -F . '{print $1"."$2}'`
		if [ $((INDEX+1)) -eq $NR_ELEMENTS ]; then
			LIST_SORTED_STRIPPED+=$KERNEL
		else
			NEXT_MAJOR=`echo ${LIST_ARRAY[$((INDEX+1))]} | awk -F . '{print $1"."$2}'`
			if [ "$NEXT_MAJOR" != "$CURRENT_MAJOR" ]; then
				LIST_SORTED_STRIPPED+="$KERNEL "
			fi
		fi
	done

	for KERNEL in $LIST_SORTED_STRIPPED; do
		if [ "$KERNEL_BASE" = "" ]; then
			KERNEL_BASE=$KERNEL
			KERNEL_LIST=$KERNEL
		else
			KERNEL_LIST="$KERNEL_LIST,$KERNEL"
		fi
	done
fi

KERNEL_LIST_ITER=`echo $KERNEL_LIST | sed -e 's/,/ /g'`

declare -a GOOD_STRINGS
declare -a GOOD_COLOURS
declare -a BAD_STRINGS
declare -a BAD_COLOURS

GOOD_STRINGS[0]="Satisfactory"
GOOD_STRINGS[1]="Good"
GOOD_STRINGS[2]="Great"
GOOD_STRINGS[3]="Excellent"
BAD_STRINGS[0]="Unsatisfactory"
BAD_STRINGS[1]="Bad"
BAD_STRINGS[2]="Awful"
BAD_STRINGS[3]="Abominable"

GOOD_COLOURS[3]="#4d9221"
GOOD_COLOURS[2]="#7fbc41"
GOOD_COLOURS[1]="#b8e186"
GOOD_COLOURS[0]="#e6f5d0"

BAD_COLOURS[3]="#c51b7d"
BAD_COLOURS[2]="#de77ae"
BAD_COLOURS[1]="#f1b6da"
BAD_COLOURS[0]="#fde0ef"

UNKNOWN_COLOUR="#FFFFFF"
NEUTRAL_COLOUR="#A0A0A0"

function removetrailingcomma() {
	sed '$ s/,\s*$//' <<< "$1"
}

function isnan() {
	# "nan" comes from libc, "NaN" from Perl itself.
	test $1 = "nan" -o \
		$1 = "+nan" -o \
		$1 = "-nan" -o \
		$1 = "NaN" -o \
		$1 = "+NaN" -o \
		$1 = "-NaN"
}

function isinf() {
	test $1 = "inf" -o \
		$1 = "+inf" -o \
		$1 = "-inf" -o \
		$1 = "Inf" -o \
		$1 = "+Inf" -o \
		$1 = "-Inf"
}

function subreportjson() {
	# The first argument COMPARISONS is a string composed by elements
	# like "3.1415 Excellent #007800" separated by commas.
	# Example:
	# "0 Excellent #007800,0 Abominable #780000,0 Satisfactory #00EE00"
	COMPARISONS=$1
	SUBREPORT=$2
	IFS=, read -r -a CMPS <<< "$COMPARISONS"
	if [ "$FORMAT" != "json" ]; then
		for ELEM in "${CMPS[@]}" ; do
			read -r GRATIO DESCRIPTION COLOUR <<< $ELEM
			printf "%8.4f %-15s " $GRATIO $DESCRIPTION
		done
	else
		echo "\"$SUBREPORT\": {"
		if [ "$REPORTROOT" != "" ]; then
			echo "\"link\": \"$REPORTROOT#$SUBREPORT\","
		fi
		echo -n "\"title\": \""
		cat $COMPARE_FILE \
			| sed 's/\\/\\\\/g' \
			| sed 's/$/\\n/' \
			| tr --delete '\n'
		echo "\","
		echo "\"comparisons\": ["
		TMP=
		for ELEM in "${CMPS[@]}" ; do
			read -r GRATIO DESCRIPTION COLOUR <<< $ELEM
			TMP+="{\"bgcolor\": \"$COLOUR\","
			TMP+="\"description\": \"$DESCRIPTION\","
			TMP+="\"value\": $GRATIO},"
		done
		TMP=$(IFS= removetrailingcomma "$TMP")
		echo $TMP
		echo "]"
		echo "}"
	fi
}

KERNEL_LIST_SPACE=`echo $KERNEL_LIST | sed -e 's/,/ /g'`
read -a KERNEL_NAMES <<< $KERNEL_LIST_SPACE

SUBREPORTSJSON=
for SUBREPORT in $(run_report_name $KERNEL_BASE); do
	COMPARE_CMD="compare-mmtests.pl --json-export --print-ratio -d . -b $SUBREPORT -n $KERNEL_LIST"

	case $SUBREPORT in
	*)
		COMPARE_FILE=`mktemp`
		$COMPARE_CMD > $COMPARE_FILE
		GMEAN=`grep ^Gmean $COMPARE_FILE`
		DMEAN=`grep ^Dmean $COMPARE_FILE`
		GOODNESS=Unknown
		COLOUR=$UNKNOWN_COLOUR
		RATIO=0
		DESCRIPTION=Unknown

		if [ "$FORMAT" != "json" ]; then
			printf "%-20s %-8s" $SUBREPORT $GOODNESS
		fi

		COMPARISONS=
		if [ -n "$DMEAN" ]; then
			GOODNESS=`echo $GMEAN | awk '{print $2}'`
			NR_FIELDS=`echo $GMEAN | awk '{print NF}'`
			if [ $NR_FIELDS -gt 3 ]; then
				FIELD_LIST=`seq 4 $NR_FIELDS`
			else
				FIELD_LIST=3
			fi
			NAME_INDEX=-1
			for FIELD in $FIELD_LIST; do
				NAME_INDEX=$((NAME_INDEX+1))
				GRATIO=`echo $GMEAN | awk "{print \\$$FIELD}"`
				DDIFF=`echo $DMEAN | awk "{print \\$$FIELD}"`
				if ! isnan "$DDIFF" && ! isinf "$DDIFF"; then
					DIFF_ADJUSTED=`perl -e "printf \"%d\", (($DDIFF*10000))"`
					DELTA=$((DIFF_ADJUSTED))
					if [ "$TOPOUT" != "" ]; then
						if [ "$TOPLATEST" != "yes" -o $FIELD -eq $NR_FIELDS ]; then
							echo "$DDIFF $GRATIO $SUBREPORT $TABLEID ${KERNEL_NAMES[$NAME_INDEX]}" >> $TOPOUT
						fi
					fi
					if [ $DIFF_ADJUSTED -lt 0 ]; then
						DELTA=$((-DIFF_ADJUSTED))
					fi

					if [ $DELTA -lt 10000 ]; then
						DESCRIPTION="Neutral"
						COLOUR=$NEUTRAL_COLOUR
					else
						INDEX=
						if [ $DELTA -lt 20000 ]; then
							INDEX=0
						elif [ $DELTA -le 30000 ]; then
							INDEX=1
						elif [ $DELTA -le 40000 ]; then
							INDEX=2
						else
							INDEX=3
						fi

						if [ "$GOODNESS" = "Higher" ]; then
							if [ $DIFF_ADJUSTED -gt 0 ]; then
								DESCRIPTION=${GOOD_STRINGS[$INDEX]}
								COLOUR=${GOOD_COLOURS[$INDEX]}
							else
								DESCRIPTION=${BAD_STRINGS[$INDEX]}
								COLOUR=${BAD_COLOURS[$INDEX]}
							fi
						else
							if [ $DIFF_ADJUSTED -lt 0 ]; then
								DESCRIPTION=${GOOD_STRINGS[$INDEX]}
								COLOUR=${GOOD_COLOURS[$INDEX]}
							else
								DESCRIPTION=${BAD_STRINGS[$INDEX]}
								COLOUR=${BAD_COLOURS[$INDEX]}
							fi
						fi
					fi
				fi
				if ! isnan "$GRATIO" && ! isinf "$GRATIO"; then
					COMPARISONS+="$GRATIO $DESCRIPTION $COLOUR,"
				else
					# nan isn't a valid JSON value (nor NaN for that matter).
					COMPARISONS+="null Unknown $UNKNOWN_COLOUR,"
				fi
			done
			COMPARISONS=$(IFS= removetrailingcomma "$COMPARISONS")
			SUBREPORTSJSON+=$(subreportjson "$COMPARISONS" $SUBREPORT)", "
		elif [ -n "$GMEAN" ]; then
			GOODNESS=`echo $GMEAN | awk '{print $2}'`
			NR_FIELDS=`echo $GMEAN | awk '{print NF}'`
			if [ $NR_FIELDS -gt 3 ]; then
				FIELD_LIST=`seq 4 $NR_FIELDS`
			else
				FIELD_LIST=3
			fi
			for FIELD in $FIELD_LIST; do
				RATIO=`echo $GMEAN | awk "{print \\$$FIELD}"`
				if ! isnan "$RATIO" && ! isinf "$RATIO"; then
					RATIO_ADJUSTED=`perl -e "printf \"%d\", (($RATIO*10000))"`
					DMEAN=`perl -e "printf \"%4.2f\", (abs (1-$RATIO))"`
					DELTA=$((RATIO_ADJUSTED-10000))
					if [ $DELTA -lt 0 ]; then
						DELTA=$((-DELTA))
					fi
					if [ "$TOPOUT" != "" ]; then
						if [ "$TOPLATEST" != "yes" -o $FIELD -eq $NR_FIELDS ]; then
							echo "$DMEAN $RATIO $SUBREPORT $TABLEID ${KERNEL_NAMES[$NAME_INDEX]}" >> $TOPOUT
						fi
					fi


					if [ $DELTA -lt 100 ]; then
						DESCRIPTION="Neutral"
						COLOUR=$NEUTRAL_COLOUR
					else
						INDEX=
						if [ $DELTA -lt 200 ]; then
							INDEX=0
						elif [ $DELTA -le 500 ]; then
							INDEX=1
						elif [ $DELTA -le 1000 ]; then
							INDEX=2
						else
							INDEX=3
						fi

						if [ "$GOODNESS" = "Higher" ]; then
							if [ $RATIO_ADJUSTED -gt 10000 ]; then
								DESCRIPTION=${GOOD_STRINGS[$INDEX]}
								COLOUR=${GOOD_COLOURS[$INDEX]}
							else
								DESCRIPTION=${BAD_STRINGS[$INDEX]}
								COLOUR=${BAD_COLOURS[$INDEX]}
							fi
						else
							if [ $RATIO_ADJUSTED -lt 10000 ]; then
								DESCRIPTION=${GOOD_STRINGS[$INDEX]}
								COLOUR=${GOOD_COLOURS[$INDEX]}
							else
								DESCRIPTION=${BAD_STRINGS[$INDEX]}
								COLOUR=${BAD_COLOURS[$INDEX]}
							fi
						fi
					fi
					COMPARISONS+="$RATIO $DESCRIPTION $COLOUR,"
				else
					# nan isn't a valid JSON value (nor NaN for that matter).
					COMPARISONS+="null Unknown $UNKNOWN_COLOUR,"
				fi
			done
			COMPARISONS=$(IFS= removetrailingcomma "$COMPARISONS")
			SUBREPORTSJSON+=$(subreportjson "$COMPARISONS" $SUBREPORT)", "
		else
			SUBREPORTSJSON+=$(subreportjson "0 Unknown $UNKNOWN_COLOUR" $SUBREPORT)", "
		fi
		rm $COMPARE_FILE
	esac
done

if [ "$FORMAT" = "json" ]; then
	printf '%s\n' "{"
	printf '%s\n' "\"table-id\": \"$TABLEID\","
	printf '%s\n' "\"subreports\" :"
	printf '%s\n' "{"
	printf '%s\n' "$(IFS= removetrailingcomma "$SUBREPORTSJSON")"
	printf '%s\n' "}"
	printf '%s\n' "}"
fi
