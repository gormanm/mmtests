#!/bin/bash
# Optionally caches results in a directory so multiple invocations run quickly
# after the first one

HASHFILE=/tmp/cache-mmtests.$$
HASHDIR=
MMTESTS_LOGDIR=
cleanup() {
	rm -f $HASHFILE
	if [ "$HASHDIR" != "" ]; then
		if [ ! -e "$CACHE_MMTESTS/$HASHDIR/cache.gz" ]; then
			rm -rf "$CACHE_MMTESTS/$HASHDIR"
		fi
	fi
}
trap cleanup EXIT

if [ "$CACHE_MMTESTS" = "" ]; then
	exec $@
fi

ORIG_PWD=`pwd`

# Create orig cache directory
if [ ! -d $CACHE_MMTESTS ]; then
	mkdir -p $CACHE_MMTESTS
	if [ $? -ne 0 ]; then
		exec $@
	fi
fi
echo "Command: $@" > $HASHFILE
echo "NR_ARGS: $#" >> $HASHFILE
for i in `seq 1 $#`; do
	if [ "${!i}" = "-d" ]; then
		i=$((i+1))
		MMTESTS_LOGDIR=${!i}
		cd $MMTESTS_LOGDIR
		if [ $? -ne 0 ]; then
			cd $ORIG_PWD
			exec $@
		fi

		echo "Log directory `pwd`" >> $HASHFILE
		if [ `ls tests-timestamp* 2> /dev/null | wc -l` -eq 0 ]; then
			cd $ORIG_PWD
			exec $@
		fi
		cd $ORIG_PWD
	fi
done

lock_hashdir() {
	while [ -e "$CACHE_MMTESTS/$HASHDIR/lockdir" ]; do
		sleep 1
	done
	mkdir $CACHE_MMTESTS/$HASHDIR/lockdir
	if [ $? -ne 0 ]; then
		while [ -e "$CACHE_MMTESTS/$HASHDIR/lockdir" ]; do
			sleep 1
		done
	fi
}
unlock_hashdir() {
	rmdir "$CACHE_MMTESTS/$HASHDIR/lockdir"
}

HASH=`cat $HASHFILE | md5sum | awk '{print $1}'`
HASH_TOPLEVEL=`echo $HASH | head -c 3`
HASHDIR="$HASH_TOPLEVEL/$HASH"
if [ -d "$CACHE_MMTESTS/$HASHDIR" ]; then
	lock_hashdir

	# Check results are still valid
	RESULTS_VALID=yes
	if [ "$MMTESTS_LOGDIR" != "" ]; then

		cd $MMTESTS_LOGDIR
		for FILE in `ls tests-timestamp-*`; do
			if [ -e "$CACHE_MMTESTS/$HASHDIR/$FILE" ]; then
				OLD_HASH=`cat "$CACHE_MMTESTS/$HASHDIR/$FILE"`
				NEW_HASH=`cat $FILE | md5sum | awk '{print $1}'`
				if [ "$OLD_HASH" != "$NEW_HASH" ]; then
					RESULTS_VALID=no
				fi
			fi
		done
		cd $ORIG_PWD
	fi
	if [ "$RESULTS_VALID" = "yes" ]; then
		zcat "$CACHE_MMTESTS/$HASHDIR/cache.gz"
		RET=$?
		if [ $RET -ne 0 ]; then
			eval $@
			RET=$?
		fi
		unlock_hashdir
		exit $RET
	fi

	# Thrash invalid cache
	rm -rf "$CACHE_MMTESTS/$HASHDIR"
fi

# Create new results
mkdir -p $CACHE_MMTESTS/$HASHDIR
if [ $? -ne 0 ]; then
	exec $@
fi
lock_hashdir
cp $HASHFILE "$CACHE_MMTESTS/$HASHDIR/hashfile"
eval $@ > "$CACHE_MMTESTS/$HASHDIR/cache.tmp"
if [ $? -ne 0 ]; then
	cat "$CACHE_MMTESTS/$HASHDIR/cache.tmp"
	rm -rf "$CACHE_MMTESTS/$HASHDIR"
	exit -1
fi

gzip "$CACHE_MMTESTS/$HASHDIR/cache.tmp"
mv "$CACHE_MMTESTS/$HASHDIR/cache.tmp.gz" "$CACHE_MMTESTS/$HASHDIR/cache.gz"
zcat "$CACHE_MMTESTS/$HASHDIR/cache.gz"

# Cache tests-timestamp md5sums
if [ "$MMTESTS_LOGDIR" != "" ]; then
	cd $MMTESTS_LOGDIR
	for FILE in `ls tests-timestamp-*`; do
		cat $FILE | md5sum | awk '{print $1}' > "$CACHE_MMTESTS/$HASHDIR/$FILE"
	done
fi

unlock_hashdir
exit 0
