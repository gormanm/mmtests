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

TEMP=`mktemp`

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
	*)
		EXTRACT_ARGS="$EXTRACT_ARGS $1"
		shift
		;;
	esac
done

# for cycle used just to get the first test easily, breaks after first iteration
for TEST in $TEST_LIST; do
	# Read graph information as described by extract-mmtests.pl
	TYPE=`$SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-type`
	DATATYPE=`echo $TYPE | cut -d, -f1`
	break
done

# This is far from ideal...
SUPPORTED_DATATYPES="WalltimeOutliers"
[[ $SUPPORTED_DATATYPES =~ $DATATYPE ]] || exit 1

echo "source (\"$SCRIPTDIR/lib/R/stats.R\")"					>> $TEMP
echo "results <- list()"							>> $TEMP

TITLES=
for TEST in $TEST_LIST; do
		$SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-header > $TMPDIR/$TEST || exit
	if [ `wc -l $TMPDIR/$TEST | awk '{print $1}'` -eq 0 ]; then
		continue
	fi
	RESULTS="$TMPDIR/$TEST"
	
	echo "results[[\"$TEST\"]] <- read.table(\"$RESULTS\", header=TRUE)"	>> $TEMP
	
done

echo "stats <- calc.stats(results, \"$DATATYPE\")"				>> $TEMP
echo "write.table(stats, \"$TMPDIR/Rstats\", sep=';', quote=FALSE)"		>> $TEMP

cat $TEMP | R --vanilla > $TMPDIR/Rlog
compare-mmtests.pl -d . $EXTRACT_ARGS $FORMAT_CMD -n $KERNEL_LIST --R-summary=$TMPDIR/Rstats
