#!/bin/bash

SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`

EXTRACT_ARGS=
TEST_LIST=
TMPDIR=
TITLE=
METRIC=
SMOOTH=
YRANGE_COMMAND=
XRANGE_COMMAND=
EXTRACT_PARAM="--print-plot"
FREQUENCY_TRIM_RIGHT=
FREQUENCY_BINWIDTH=
FREQUENCY_CUMULATIVE=
FREQDIST_CMD=

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
	--metric)
		METRIC="$2"
		shift 2
		;;
	--title)
		TITLE="$2"
		shift 2
		;;
	--format)
		FORMAT="$2"
		shift 2
		;;
	--plottype)
		PLOTTYPE_OVERRIDE="$2"
		shift 2
		;;
	--output)
		OUTPUT_TEMPLATE="$2"
		shift 2
		;;
	--smooth)
		SMOOTH="--smooth bezier"
		shift
		;;
	--with-smooth)
		WITH_SMOOTH="--smooth bezier"
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
	--very-wide)
		WIDE=--very-wide
		shift
		;;
	--large)
		WIDE=--large
		shift
		;;
	--very-large)
		WIDE=--very-large
		shift
		;;
	--rotate-xaxis)
		ROTATE_XAXIS=--rotate-xaxis
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
		XRANGE_COMMAND="--xrange 0:100"
		FORCE_X_LABEL="Max at percentage of samples"
		XTICS_CMD="--xtics $2"
		SORT_PERCENTAGES=$2
		shift 2
		;;
	--xtics)
		XTICS_CMD="--xtics $2"
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
	--freq)
		FREQUENCY=yes
		EXTRACT_PARAM=
		shift
		;;
	--freq-trim-right)
		FREQUENCY=yes
		EXTRACT_PARAM=
		FREQUENCY_TRIM_RIGHT="$2"
		FREQUENCY_PARAM+="--trim-right $FREQUENCY_TRIM_RIGHT "
		shift 2
		;;
	--freq-binwidth)
		FREQUENCY=yes
		EXTRACT_PARAM=
		FREQUENCY_BINWIDTH="$2"
		FREQUENCY_PARAM+="--bin-width $FREQUENCY_BINWIDTH "
		shift 2
		;;
	--freq-cumulative)
		FREQUENCY=yes
		FREQUENCY_CUMULATIVE=yes
		FREQUENCY_PARAM+="--cumulative "
		shift
		;;
	-b)
		SUBREPORT="$2"
		EXTRACT_ARGS+=" $1 $2"
		SUBREPORT_ARGS="--subreport $SUBREPORT"
		shift 2
		;;
	-a)
		ALTREPORT="$2"
		EXTRACT_ARGS+=" $1 $2"
		shift 2
		;;
	--sub-heading)
		EXTRACT_ARGS+=" $1 $2"
		SUBHEADING="$2"
		[ "$METRIC" = "" ] && METRIC=`echo $SUBHEADING | sed -e 's/[\^\$]//g'`
		shift 2
		;;
	--print-monitor)
		EXTRACT_ARGS+=" $1 $2"
		PRINT_MONITOR=yes
		shift 2
		;;
	*)
		echo $1 | grep -q ' '
		if [ $? -eq 0 ]; then
			EXTRACT_ARGS+=" \"$1\""
		else
			EXTRACT_ARGS+=" $1"
		fi
		shift
		;;
	esac
done

lookup_yaml() {
	SHELLPACK_YAML="$SCRIPTDIR/../shellpack_src/src/$SUBREPORT/shellpack.yaml"
	[ -e $SHELLPACK_YAML ] && return

	local _subreport=$SUBREPORT
	local _yaml=$SHELLPACK_YAML

	while [ ! -e $_yaml ]; do
		if ! [[ $_subreport =~ - ]]; then
			return
		fi
		_subreport=`echo $_subreport | sed 's/\(.*\)-.*/\1/'`
		_yaml="$SCRIPTDIR/../shellpack_src/src/$_subreport/shellpack.yaml"
	done
	SHELLPACK_YAML=$_yaml
}
lookup_yaml

EXTRACT_ARGS=`echo "$EXTRACT_ARGS" | sed -e 's/\\$/\\\\$/g'`
lookup_metric() {
	if [ "$METRIC" = "" -a -e $SHELLPACK_YAML ]; then
		METRIC=`yq '."default-metric"' $SHELLPACK_YAML | sed -e 's/\"//g'`
	fi
}

lookup_type() {
	if [ "$PRINT_MONITOR" = "yes" -o ! -e $SHELLPACK_YAML ]; then
		TYPE=`$SCRIPTDIR/extract-mmtests.pl --format script -n $TEST $EXTRACT_ARGS --print-type`
		XLABEL=`echo $TYPE | cut -d, -f2`
		YLABEL=`echo $TYPE | cut -d, -f3`
		[ "$PLOTTYPE" = "" ] && PLOTTYPE=`echo $TYPE | cut -d, -f4`
		return
	fi

	if [ "$FREQUENCY" = "yes" ]; then
		PLOTTYPE="linespoint"
		XLABEL="Sample Value"
		YLABEL="Percentage"
		return
	fi

	XLABEL=`yq '.PlotXaxis' $SHELLPACK_YAML | sed -e 's/"//g'`
	[ "$PLOTTYPE" = "" ]	 && PLOTTYPE=`yq .\"$METRIC\".PlotType $SHELLPACK_YAML 2>/dev/null | sed -e 's/"//g'`
	[ "$PLOTTYPE" = "null" ] && PLOTTYPE=`yq .PlotType $SHELLPACK_YAML 2>/dev/null | sed -e 's/"//g'`
	[ "$PLOTTYPE" = "" ]	 && PLOTTYPE="operation-candlesticks"

	YLABEL=
	METRIC_BASE=${METRIC//-[0-9]*}
	YDESC=`yq .\"$METRIC_BASE\".title $SHELLPACK_YAML |sed -e 's/"//g'`
	[ "$YDESC" != "null" ] && YLABEL="$YDESC\\n"
	YUNITS=`yq .\"$METRIC_BASE\".units $SHELLPACK_YAML | sed -e 's/"//g'`
	if [ "$YUNITS" = "null" ]; then
		YUNITS=`yq .units $SHELLPACK_YAML | sed -e 's/"//g'`
		if [ "$YUNITS" = "null" ]; then
			YLABEL="Unknown units .$METRIC.units"
			return
		fi
	fi
	UNIT_LABEL=`$SCRIPTDIR/lookup-unit-label $YUNITS`

	if [ "$YDESC" = "$UNIT_LABEL" ]; then
		YLABEL=""
	fi
	YLABEL+="$UNIT_LABEL"
}

lookup_title() {
	if [ "$TITLE" != "" ]; then
		return
	fi

	if [ ! -e $SHELLPACK_YAML ]; then
		TITLE="Default Title"
		return
	fi

	if [ "$FREQUENCY" = "yes" ]; then
		TITLE="Frequency Distribution for $SUBREPORT.$METRIC"
		if [ "$FREQUENCY_CUMULATIVE" = "yes" ]; then
			TITLE="Cumulative $TITLE"
		fi
		TITLE_EXTRA=
		[ "$FREQUENCY_BINWIDTH"   != "" ] && TITLE_EXTRA+="binwidth=$FREQUENCY_BINWIDTH "
		[ "$FREQUENCY_TRIM_RIGHT" != "" ] && TITLE_EXTRA+="trim-right=$FREQUENCY_TRIM_RIGHT% "
		[ "$TITLE_EXTRA" != "" ]	  && TITLE+="\\n$TITLE_EXTRA"
		return
	fi

	TITLE=`yq .\"$METRIC\".title $SHELLPACK_YAML | sed -e 's/"//g'`
	[ "$TITLE" = "null" ] && TITLE="Unknown Title for $SUBREPORT.$METRIC"
}

# for cycle used just to get the first test easily, breaks after first iteration
for TEST in $TEST_LIST; do
	# Read graph information as described by extract-mmtests.pl or shellpack.yaml
	lookup_metric
	lookup_type
	lookup_title

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
		echo "TRACE: $SCRIPTDIR/extract-mmtests.pl --format script -n $TEST $EXTRACT_ARGS --print-type"
		echo "TRACE: YAML     $SHELLPACK_YAML"
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
	EXTRACT_CMD="$SCRIPTDIR/extract-mmtests.pl --format script -n $TEST $EXTRACT_ARGS $EXTRACT_PARAM"
	[ "$PLOTTYPE_OVERRIDE" != "" ] && EXTRACT_CMD+=" --plot-type $PLOTTYPE_OVERRIDE"
	[ "$METRIC" != "" -a "$SUBHEADING" = "" ] && EXTRACT_CMD+=" --sub-heading $METRIC"
	[ "$GRAPH_DEBUG" = "yes" ] && echo "TRACE: Extract: $EXTRACT_CMD"
	METRIC_ESC=`echo $METRIC | sed -e 's/\//\\\\\\//g'`
	eval $EXTRACT_CMD					| \
		grep -v nan 					| \
		sed -e 's/_/\\\\_/g' -e "s/$METRIC_ESC-//"	  \
		> $PLOTFILE || exit

	if [ "$FREQUENCY" = "yes" ]; then
		FREQUENCY_CMD="$SCRIPTDIR/freq-to-pct"
		[ "$FREQUENCY_TRIM_RIGHT" != "" ] && FREQ_CMD+=" --trim-right $FREQUENCY_TRIM_RIGHT"
		[ "$FREQUENCY_BINWIDTH"   != "" ] && FREQ_CMD+=" --binwidth   $FREQUENCY_BINWIDTH"
		[ "$GRAPH_DEBUG" = "yes"	] && cp $PLOTFILE /tmp/last-freqdist-in
		cat $PLOTFILE | $FREQUENCY_CMD $FREQUENCY_PARAM > $PLOTFILE.tmp
		mv $PLOTFILE.tmp $PLOTFILE
		[ "$GRAPH_DEBUG" = "yes"	] && cp $PLOTFILE /tmp/last-freqdist-out
	fi

	if [ "$SORT_SAMPLES" = "yes" ]; then
		SORT_SWITCH=
		if [ "$SORT_REVERSE" = "yes" ]; then
			SORT_SWITCH=-r
		fi
		if [ "$SORT_PERCENTAGES" = "" ]; then
			sort $SORT_SWITCH -k2 -n $PLOTFILE | awk '{print NR" "$2}' > $PLOTFILE.tmp
		else
			NR_SAMPLES=`cat $PLOTFILE | wc -l`
			sort $SORT_SWITCH -k2 -n $PLOTFILE | awk "{print (NR*100/$NR_SAMPLES)\" \"\$2}" > $PLOTFILE.tmp
		fi
		mv $PLOTFILE.tmp $PLOTFILE
	fi

	if [ "$GRAPH_DEBUG" = "yes" ]; then
		echo TRACE: Writing /tmp/lastplot
		cp $PLOTFILE /tmp/lastplot
	fi
	if [ "$PLOTTYPE" = "--operation-candlesticks" ]; then
		OFFSET=`perl -e "print (1+$COUNT*0.3)"`
		awk "\$1=(\$1+$COUNT*0.3)" $PLOTFILE > $PLOTFILE.tmp
		mv $PLOTFILE.tmp $PLOTFILE
		COUNT=$((COUNT+1))
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

if [ "$FREQUENCY" = "yes" ]; then
	FREQDIST_CMD="--freqdist"
fi
for PLOTSCRIPT in $PLOTSCRIPTS; do
	if [ "$OUTPUT_TEMPLATE" != "" ]; then
		OUTPUT_TEMPLATE=`echo $OUTPUT_TEMPLATE | sed -e "s/\.$FORMAT$//"`
		FORMAT_CMD="--format \"$FORMAT\""
		OUTPUT_CMD="--output \"$OUTPUT_TEMPLATE.$FORMAT\""
	fi
	TITLE_CMD="--title \"$TITLE\""
	COMMAND="$SCRIPTDIR/$PLOTSCRIPT $TITLE_CMD $PLOTTYPE $SMOOTH $FORMAT_CMD 	\
		$WIDE $SUBREPORT_ARGS$ALTREPORT $XRANGE $XRANGE_COMMAND $YRANGE_COMMAND	\
		$ROTATE_XAXIS $XTICS_CMD $FREQDIST_CMD \
		--xlabel \"$XLABEL\" \
		--ylabel \"$YLABEL\" \
		--titles $TITLES"
	if [ "$GRAPH_DEBUG" = "yes" ]; then
		echo TRACE: $COMMAND $OUTPUT_CMD $PLOTS
	fi
	eval $COMMAND $OUTPUT_CMD $TITLE_CMD $LOGX $LOGY $PLOTS
	if [ "$WITH_SMOOTH" != "" ]; then
		TITLE_CMD="--title \"$TITLE smooth\""
		OUTPUT_CMD="--output \"$OUTPUT_TEMPLATE-smooth.$FORMAT\""
		eval $COMMAND $OUTPUT_CMD $TITLE_CMD $WITH_SMOOTH $PLOTS
	fi
	if [ "$GRAPH_DEBUG" = "yes" ]; then
		for PLOT in $PLOTS; do
			echo
			echo TRACE: Dump plot data $PLOT
			cat $PLOT
		done
	fi
done
