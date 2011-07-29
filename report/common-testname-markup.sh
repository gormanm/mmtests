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
TIMESTAMP=`tail -1 tests-timestamp-$KERNEL | awk '{print $3}'`
TIMESTAMP=$((($TIMESTAMP-$START)/60))
MIRROR="$MIRROR, '' $TIMESTAMP"

echo "set grid x2tics" > $TMPDIR/$NAME-extra
echo "set x2tics mirror ($MIRROR) rotate by 45" >> $TMPDIR/$NAME-extra


