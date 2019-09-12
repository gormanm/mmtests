#!/bin/bash
SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`

EXTRACT_ARGS=
TEST_LIST=
TMPDIR=
TITLE="--title \"Default Title\""
SMOOTH=
YRANGE_COMMAND=
XRANGE_COMMAND=

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
	--yrange)
		YRANGE_COMMAND="--yrange $2"
		shift 2
		;;
	--xrange)
		XRANGE_COMMAND="--xrange $2"
		shift 2
		;;
	--sort-percentages)
		XRANGE_COMMAND="--xrange 0:102"
		FORCE_X_LABEL="Max at percentage of samples"
		XTICS_CMD="--xtics $2"
		SORT_PERCENTAGES=$2
		shift 2
		;;
	--sort-samples)
		SORT_SAMPLES=yes
		shift
		;;
	--sort-samples-reverse)
		SORT_SAMPLES=yes
		SORT_REVERSE=yes
		shift
		;;
	-b)
		SUBREPORT="$2"
		EXTRACT_ARGS="$EXTRACT_ARGS $1 $2"
		SUBREPORT_ARGS="--subreport $SUBREPORT"
		shift 2
		;;
	-a)
		ALTREPORT="$2"
		EXTRACT_ARGS="$EXTRACT_ARGS $1 $2"
		shift 2
		;;
	*)
		echo $1 | grep -q ' '
		if [ $? -eq 0 ]; then
			EXTRACT_ARGS="$EXTRACT_ARGS \"$1\""
		else
			EXTRACT_ARGS="$EXTRACT_ARGS $1"
		fi
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

	if [ "$GRAPH_DEBUG" = "yes" ]; then
		echo "TRACE: $SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-type"
		echo "TRACE: TYPE     $TYPE"
		echo "TRACE: XLABEL   $XLABEL"
		echo "TRACE: YLABEL   $YLABEL"
		echo "TRACE: PLOTTYPE $PLOTTYPE"
	fi
	break
done

if [ "$PLOTTYPE_OVERRIDE" != "" ]; then
	PLOTTYPE="--plottype $PLOTTYPE_OVERRIDE"
fi

TITLES=
COUNT=0
for TEST in $TEST_LIST; do
	PLOTFILE="$TMPDIR/$TEST"
	eval $SCRIPTDIR/cache-mmtests.sh $SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-plot | \
		grep -v nan 		| \
		sed -e 's/_/\\\\_/g'	  \
		> $PLOTFILE || exit

	NR_SAMPLES=`cat $PLOTFILE | wc -l`

	if [ "$SORT_SAMPLES" = "yes" ]; then
		NR_SAMPLE=0
		SORT_SWITCH=
		if [ "$SORT_REVERSE" = "yes" ]; then
			SORT_SWITCH=-r
		fi
		if [ "$SORT_PERCENTAGES" = "" ]; then
			sort $SORT_SWITCH -k2 -n $PLOTFILE | awk '{print NR" "$2}' > $PLOTFILE.tmp
		else
			sort $SORT_SWITCH -k2 -n $PLOTFILE | awk "{print (NR*100/$NR_SAMPLES)\" \"\$2}" > $PLOTFILE.tmp
		fi
		mv $PLOTFILE.tmp $PLOTFILE
	fi

	if [ "$GRAPH_DEBUG" = "yes" ]; then
		echo TRACE: $SCRIPTDIR/extract-mmtests.pl -n $TEST $EXTRACT_ARGS --print-plot
		echo TRACE: Writing /tmp/lastplot
		cp $PLOTFILE /tmp/lastplot
	fi
	if [ "$PLOTTYPE" = "--operation-candlesticks" ]; then
		OFFSET=`perl -e "print (1+$COUNT*0.3)"`
		awk "\$1=(\$1+$COUNT*0.3)" $PLOTFILE > $PLOTFILE.tmp
		mv $PLOTFILE.tmp $PLOTFILE
		COUNT=$((COUNT+1))
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
	if [ $COUNT -eq 1 ]; then
		COUNT=2
	fi
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

[ "$TITLES" == "" ] && exit 0

for PLOTSCRIPT in $PLOTSCRIPTS; do
	COMMAND="$SCRIPTDIR/$PLOTSCRIPT $TITLE $PLOTTYPE $SMOOTH $FORMAT_CMD $OUTPUT_CMD $OUTPUT \
		$LOGX $LOGY $WIDE $SUBREPORT_ARGS$ALTREPORT $XRANGE $XRANGE_COMMAND $YRANGE_COMMAND $XTICS_CMD \
		--xlabel \"$XLABEL\" \
		--ylabel \"$YLABEL\" \
		--titles $TITLES \
		$PLOTS"
	if [ "$GRAPH_DEBUG" = "yes" ]; then
		echo TRACE: $COMMAND
	fi
	eval $COMMAND && break
	echo
	cat $PLOTSCRIPT
done
