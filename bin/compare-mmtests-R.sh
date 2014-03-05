#!/bin/bash
SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`

EXTRACT_ARGS=
TEST_LIST=
TMPDIR=

# Do Not Litter
cleanup() {
	if [ "$TMPDIR" != "" -a -d $TMPDIR ]; then
		rm -rf $TMPDIR
	fi
	exit
}
trap cleanup EXIT
trap cleanup INT
trap cleanup TERM

TMPDIR=`mktemp`
if [ "$TMPDIR" = "" ]; then
	echo ERROR: Failed to create temporary directory
	exit -1
fi
rm $TMPDIR
mkdir $TMPDIR

TEMP=`mktemp --tmpdir=$TMPDIR`

while [ "$1" != "" ]; do
	case "$1" in
	-n)
		TEST_LIST="`echo $2 | sed -e 's/,/ /g'`"
		KERNEL_LIST="$2"
		shift 2
		;;
	--format)
		FORMAT=$2
		FORMAT_CMD="--format $FORMAT"
		shift 2
		;;
	--iterations)
		ITERATIONS=$2
		shift 2
		;;
	*)
		EXTRACT_ARGS="$EXTRACT_ARGS $1"
		shift
		;;
	esac
done

[[ -n "$ITERATIONS" ]] && pushd 1 > /dev/null
# for cycle used just to get the first test easily, breaks after first iteration
for TEST in $TEST_LIST; do
	# Read graph information as described by extract-mmtests.pl
	TYPE=`$SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-type`
	DATATYPE=`echo $TYPE | cut -d, -f1`
	break
done
[[ -n "$ITERATIONS" ]] && popd > /dev/null

# This is far from ideal...
SUPPORTED_DATATYPES="WalltimeOutliers PercentageAllocated"
[[ $SUPPORTED_DATATYPES =~ $DATATYPE ]] || exit 1

echo "source (\"$SCRIPTDIR/lib/R/stats.R\")"					>> $TEMP
echo "results <- list()"							>> $TEMP

TITLES=
if [[ -z "$ITERATIONS" ]]; then
	for TEST in $TEST_LIST; do
		RESULTS="$TMPDIR/$TEST"
		$SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-header > $RESULTS || exit
		if [ `wc -l $RESULTS | awk '{print $1}'` -eq 0 ]; then
			continue
		fi
	
		echo "results[[\"$TEST\"]] <- read.table(\"$RESULTS\", header=TRUE)"	>> $TEMP
	done
else for I in `seq 1 $ITERATIONS`; do
	pushd $I > /dev/null
	for TEST in $TEST_LIST; do
		if [[ $I == 1 ]]; then
			echo "results[[\"$TEST\"]] <- data.frame()"			>> $TEMP
		fi

		RESULTS="$TMPDIR/$TEST-$I"
		$SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-header > $RESULTS || exit
		if [ `wc -l $RESULTS | awk '{print $1}'` -eq 0 ]; then
			continue
		fi

		echo "temp <- read.table(\"$RESULTS\", header=TRUE)"			>> $TEMP
		echo "temp[[\"Iteration\"]] <- $I"					>> $TEMP
		echo "results[[\"$TEST\"]] <- rbind(results[[\"$TEST\"]], temp)"	>> $TEMP
	done
	popd > /dev/null
done; fi

echo "stats <- calc.stats(results, \"$DATATYPE\")"				>> $TEMP
echo "write.table(stats, \"$TMPDIR/Rstats\", sep=';', quote=FALSE)"		>> $TEMP

cat $TEMP | R --vanilla > $TMPDIR/Rlog
[[ -n "$ITERATIONS" ]] && pushd 1 > /dev/null
pwd
compare-mmtests.pl -d . $EXTRACT_ARGS $FORMAT_CMD -n $KERNEL_LIST --R-summary=$TMPDIR/Rstats
[[ -n "$ITERATIONS" ]] && popd > /dev/null

exit 0
