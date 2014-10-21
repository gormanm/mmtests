#!/bin/bash

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/config

KERNEL_BASE=
KERNEL_COMPARE=
KERNEL_EXCLUDE=

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
	for KERNEL in `echo $LIST_SORT | sed -e 's/,/\n/g' | sort -t . -k2 -n`; do
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

GOOD_COLOURS[3]="#007800"
GOOD_COLOURS[2]="#009F00"
GOOD_COLOURS[1]="#00C700"
GOOD_COLOURS[0]="#00EE00"

BAD_COLOURS[3]="#780000"
BAD_COLOURS[2]="#9F0000"
BAD_COLOURS[1]="#C70000"
BAD_COLOURS[0]="#EE0000"

UNKNOWN_COLOUR="#FFFFFF"
NEUTRAL_COLOUR="#A0A0A0"

if [ "$FORMAT" = "html" ]; then
	echo "<table cellspacing=0>"
fi

AOPEN=
ACLOSE=
if [ "$REPORTROOT" != "" ]; then
	AOPEN="<a href=\"$REPORTROOT\">"
	ACLOSE="</a>"
fi

for SUBREPORT in `grep "test begin :: " "$FIRST_ITERATION_PREFIX"tests-timestamp-$KERNEL_BASE | awk '{print $4}'`; do
	COMPARE_CMD="compare-mmtests.pl --print-ratio -d . -b $SUBREPORT -n $KERNEL_LIST"

	case $SUBREPORT in
	*)
		GMEAN=`$COMPARE_CMD | grep ^Gmean | sed -e 's/([0-9.% -]*)//g'`
		GOODNESS=Unknown
		COLOUR=$UNKNOWN_COLOUR
		RATIO=0
		DESCRIPTION=Unknown
		if [ "$GMEAN" != "" ]; then
			GOODNESS=`echo $GMEAN | awk '{print $2}'`
			RATIO=`echo $GMEAN | awk '{print $NF}'`
			if [ "$RATIO" != "nan" ]; then
				RATIO_ADJUSTED=`perl -e "print (($RATIO*10000))"`
				DELTA=$((RATIO_ADJUSTED-10000))
				if [ $DELTA -lt 0 ]; then
					DELTA=$((-DELTA))
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
			fi
		fi

		if [ "$FORMAT" != "html" ]; then
			printf "%-20s %-8s %8.4f %-15s\n" $SUBREPORT $GOODNESS $RATIO $DESCRIPTION
		else
			echo "<tr>"
			echo "<td bgcolor=\"$COLOUR\"><font size=1>$SUBREPORT</font></td>"
			echo "<td bgcolor=\"$COLOUR\"><font size=1>$AOPEN$RATIO$ACLOSE</font></td>"
			echo "</tr>"
		fi
	esac
done

if [ "$FORMAT" = "html" ]; then
	echo "</table>"
fi
