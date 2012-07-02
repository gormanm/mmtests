for SINGLE_KERNEL in $KERNEL; do
	FIRST_KERNEL=$SINGLE_KERNEL
	break
done

LONGEST_TEST=0
for SINGLE_KERNEL in $KERNEL; do
	START=`head -1 tests-timestamp-$SINGLE_KERNEL | awk '{print $3}'`
	END=`tail -1 tests-timestamp-$SINGLE_KERNEL | awk '{print $3}'`
	DURATION=$((END-START))
	if [ $DURATION -gt $LONGEST_TEST ]; then
		LONGEST_TEST=$DURATION
		LONGEST_KERNEL=$SINGLE_KERNEL
	fi
done

COPY=$KERNEL
KERNEL=$LONGEST_KERNEL
START=`head -1 tests-timestamp-$LONGEST_KERNEL | awk '{print $3}'`

# Calculate when tests began
TESTNAMES=`grep "^test begin" tests-timestamp-$KERNEL | grep -v aim9 | awk '{print $4}'`
MIRROR=""
for TESTNAME in $TESTNAMES; do
	MIN_TIMESTAMP=99999999
	if [ "$TESTNAME" = "hackbench-sockets" ]; then
		continue
	fi
	TIFS=$IFS
	IFS="
"

	for LINE in `grep "^test begin" tests-timestamp-$KERNEL | grep $TESTNAME`; do
		TIMESTAMP=`echo $LINE | awk '{print $5}'`
		TIMESTAMP=$((($TIMESTAMP-$START)/60))

		if [ $TIMESTAMP -lt $MIN_TIMESTAMP ]; then
			MIN_TIMESTAMP=$TIMESTAMP
		fi
	done

	IFS=$TIFS

	case $TESTNAME in
		hackbench-pipes)
			TESTNAME="hackbench"
			;;
		vmr-cacheeffects)
			TESTNAME="cacheeffects"
		;;
		vmr-createdelete)
			TESTNAME="createdelete"
			;;
		stress-highalloc)
			TESTNAME="highalloc"
		;;
	esac

	if [ "$TESTNAME" = "hackbench-pipes" ]; then
		TESTNAME="hackbench"
	fi
	if [ "$MIRROR" != "" ]; then
		MIRROR="$MIRROR, "
	fi
	MIRROR="$MIRROR '$TESTNAME' $MIN_TIMESTAMP"
done

if [ "$MIRROR" != "" ]; then
	MIRROR="$MIRROR, "
fi
MIRROR="$MIRROR 'finish' $((END-START))"
TIMESTAMP=`tail -1 tests-timestamp-$KERNEL | awk '{print $3}'`
TIMESTAMP=$((($TIMESTAMP-$START)/60))

if [ "$MIRROR" != "" ]; then
	MIRROR="$MIRROR, '' $TIMESTAMP"
	echo "set grid x2tics" > $TMPDIR/$NAME-extra
	echo "set x2tics mirror ($MIRROR) rotate by 45" >> $TMPDIR/$NAME-extra
else
	echo -n > $TMPDIR/$NAME-extra
fi

KERNEL=$COPY
