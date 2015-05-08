#!/bin/bash
SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`

EXTRACT_ARGS=
TEST_LIST=
TMPDIR=
TITLE="--title \"Default Title\""
SMOOTH=

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
	echo ERROR: Failed to create temporary diretory
	exit -1
fi
rm $TMPDIR
mkdir $TMPDIR

# if R_TMPDIR was exported by caller (i.e. compare-kernels.sh) we use it and benefit
# from caching of R result objects; the cleanup is handled by caller.
# Otherwise we use self-cleaned TMPDIR for R stuff
if [ "$R_TMPDIR" == "" ]; then
	export R_TMPDIR="$TMPDIR"
fi

while [ "$1" != "" ]; do
	case "$1" in
	-n)
		TEST_LIST="`echo $2 | sed -e 's/,/ /g'`"
		shift 2
		;;
	--title)
		TITLE="--title \"$2\""
		shift 2
		;;
	--format)
		FORMAT_CMD="--format \"$2\""
		shift 2
		;;
	--plottype)
		PLOTTYPE_OVERRIDE="$2"
		shift 2
		;;
	--separate-tests)
		SEPARATE_TESTS="$1"
		shift
		;;
	--output)
		OUTPUT_CMD="--output \"$2\""
		shift 2
		;;
	--smooth)
		SMOOTH="--smooth bezier"
		shift
		;;
	--logX)
		LOGX=--logX
		shift
		;;
	--logY)
		LOGY=--logY
		shift
		;;
	--wide)
		WIDE=--wide
		shift
		;;
	--x-label)
		FORCE_X_LABEL="$2"
		shift 2
		;;
	--y-label)
		FORCE_Y_LABEL="$2"
		shift 2
		;;
	--R)
		USE_R="yes"
		shift
		;;
	-b)
		SUBREPORT="$2"
		EXTRACT_ARGS="$EXTRACT_ARGS $1 $2"
		SUBREPORT_ARGS="--subreport $SUBREPORT"
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
	XLABEL=`echo $TYPE | cut -d, -f2`
	YLABEL=`echo $TYPE | cut -d, -f3`
	PLOTTYPE=`echo $TYPE | cut -d, -f4`
	if [ "$XLABEL" = "" ]; then
		XLABEL="Unknown X Label"
	fi
	if [ "$YLABEL" = "" ]; then
		YLABEL="Unknown Y Label"
	fi

	if [ "$PLOTTYPE" != "" ]; then
		PLOTTYPE=--$PLOTTYPE
	fi
	break
done

if [ "$PLOTTYPE_OVERRIDE" != "" ]; then
	PLOTTYPE="--plottype $PLOTTYPE_OVERRIDE"
fi
if [ "$SEPARATE_TESTS" != "" ] && [ "$USE_R" == "" ]; then
	echo "--separate-tests only supported together with --R" >&2
	exit 1
fi

# This is far from ideal...
R_SUPPORTED_PLOTTYPES="boxplot candlestick candlesticks run-sequence"
if [[ -n "$USE_R" && $R_SUPPORTED_PLOTTYPES =~ $PLOTTYPE ]]; then
	echo "Plottype $PLOTTYPE not supported by R, fallback to Perl" >&2
	USE_R=""
fi

TITLES=
COUNT=0
for TEST in $TEST_LIST; do
	if [ "$USE_R" != "" ]; then
		PLOTFILE="$R_TMPDIR/$SUBREPORT-$TEST"
		if [ ! -f "$R_TMPDIR/$SUBREPORT.Rdata" ]; then
			$SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-header > $PLOTFILE || exit
		fi
	else
		PLOTFILE="$TMPDIR/$TEST"
		$SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-plot | grep -v nan > $PLOTFILE || exit
		if [ "$PLOTTYPE" = "--operation-candlesticks" ]; then
			OFFSET=`perl -e "print (1+$COUNT*0.3)"`
			awk "\$1=(\$1+$COUNT*0.3)" $PLOTFILE > $PLOTFILE.tmp
			mv $PLOTFILE.tmp $PLOTFILE
			COUNT=$((COUNT+1))
		fi
	fi
	if [ `wc -l $PLOTFILE | awk '{print $1}'` -eq 0 ]; then
		continue
	fi
	if [ "$TITLES" = "" ]; then
		TITLES=$TEST
		PLOTS="$PLOTFILE"
	else
		TITLES="$TITLES,$TEST"
		PLOTS="$PLOTS $PLOTFILE"
	fi
done
XRANGE=
if [ $COUNT -gt 0 ]; then
	MINX=0.2
	END=`wc -l $PLOTFILE | awk '{print $1}'`
	MAXX=`perl -e "print int ($END+0.5+$COUNT*0.3)"`
	XRANGE="--xrange $MINX:$MAXX"
fi

# Override certain graph options if requested
if [ "$FORCE_X_LABEL" != "" ]; then
	XLABEL=$FORCE_X_LABEL
fi
if [ "$FORCE_Y_LABEL" != "" ]; then
	YLABEL=$FORCE_Y_LABEL
fi

PLOTSCRIPTS="plot"
[ "$USE_R" != "" ] && PLOTSCRIPTS="plot-R plot"

[ "$TITLES" == "" ] && exit 0

for PLOTSCRIPT in $PLOTSCRIPTS; do
	eval $SCRIPTDIR/$PLOTSCRIPT $TITLE $PLOTTYPE $SEPARATE_TESTS $SMOOTH $FORMAT_CMD $OUTPUT_CMD $OUTPUT \
		$LOGX $LOGY $WIDE $SUBREPORT_ARGS $XRANGE \
		--xlabel \"$XLABEL\" \
		--ylabel \"$YLABEL\" \
		--titles $TITLES \
		$PLOTS && break
done
