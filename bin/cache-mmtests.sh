#!/bin/bash
# Optionally caches results in a directory so multiple invocations run quickly
# after the first one
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
. $SCRIPTDIR/../shellpacks/common.sh

HASHFILE=/tmp/cache-mmtests.$$
HASHDIR=
MMTESTS_LOGDIR=
rm_hashdir() {
	if [ "$JSON_EXPORT" = "yes" -a -L "$MMTESTS_LOGDIR/$BENCHMARK.json.xz" ]; then
		rm -f "$MMTESTS_LOGDIR/$BENCHMARK.json.xz"
	fi
	rm -rf "$CACHE_MMTESTS/$HASHDIR"
}
cleanup() {
	rm -f $HASHFILE
	if [ "$HASHDIR" != "" ]; then
		if [ "$JSON_EXPORT" = "yes" ]; then
			if ! [ -e "$CACHE_MMTESTS/$HASHDIR/cache.gz" -a -e "$CACHE_MMTESTS/$HASHDIR/cache.json.xz" -a "$CACHEFILES_SOUND" != "no" ]; then
				rm_hashdir
			fi
		else
			if ! [ -e "$CACHE_MMTESTS/$HASHDIR/cache.gz" -a "$CACHEFILES_SOUND" != "no" ]; then
				rm_hashdir
			fi
		fi
	fi
}
trap cleanup EXIT

if [ "$CACHE_MMTESTS" = "" ]; then
	exec "$@"
fi

ORIG_PWD=`pwd`

# Create orig cache directory
if [ ! -d $CACHE_MMTESTS ]; then
	mkdir -p $CACHE_MMTESTS
	if [ $? -ne 0 ]; then
		exec "$@"
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
			exec "$@"
		fi

		echo "Log directory `pwd`" >> $HASHFILE
		if ! have_run_results; then
			cd $ORIG_PWD
			exec "$@"
		fi
		cd $ORIG_PWD
	fi
done

JSON_EXPORT=no
for i in `seq 1 $#`; do
	if [ "${!i}" = "--json-export" ]; then
		JSON_EXPORT=yes
	elif [ "${!i}" = "-b" ]; then
		i=$((i+1))
		BENCHMARK=${!i}
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
		for FILE in `ls */iter-*/tests-timestamp`; do
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

		CACHEFILES_EXIST=yes
		if [ "$JSON_EXPORT" = "yes" ]; then
			if ! [ -e "$CACHE_MMTESTS/$HASHDIR/cache.gz" -a -e "$CACHE_MMTESTS/$HASHDIR/cache.json.xz" ]; then
				CACHEFILES_EXIST=no
			fi
		else
			if ! [ -e "$CACHE_MMTESTS/$HASHDIR/cache.gz" ]; then
				CACHEFILES_EXIST=no
			fi
		fi
		if [ "$CACHEFILES_EXIST" = "no" ]; then
			eval "$@"
			RET=$?
			unlock_hashdir
			exit $RET
		fi

		CACHEFILES_SOUND=yes
		if [ "$JSON_EXPORT" = "yes" ]; then
			{ zcat "$CACHE_MMTESTS/$HASHDIR/cache.gz" && xzcat "$CACHE_MMTESTS/$HASHDIR/cache.json.xz"; } > /dev/null
			if [ $? -ne 0 ]; then
				CACHEFILES_SOUND=no
			fi
		else
			zcat "$CACHE_MMTESTS/$HASHDIR/cache.gz" > /dev/null
			if [ $? -ne 0 ]; then
				CACHEFILES_SOUND=no
			fi
		fi
		if [ "$CACHEFILES_SOUND" = "no" ]; then
			eval "$@"
			RET=$?
			unlock_hashdir
			exit $RET
		fi

		zcat "$CACHE_MMTESTS/$HASHDIR/cache.gz"
		RET=$?
		if [ "$JSON_EXPORT" = "yes" ]; then
			ln -s -f "$CACHE_MMTESTS/$HASHDIR/cache.json.xz" "$MMTESTS_LOGDIR/$BENCHMARK.json.xz"
			RET=$((RET || $?))
		fi
		unlock_hashdir
		exit $RET
	fi

	# Thrash invalid cache
	rm_hashdir
fi

# Create new results
mkdir -p $CACHE_MMTESTS/$HASHDIR
if [ $? -ne 0 ]; then
	exec "$@"
fi
lock_hashdir
cp $HASHFILE "$CACHE_MMTESTS/$HASHDIR/hashfile"
eval "$@" > "$CACHE_MMTESTS/$HASHDIR/cache.tmp"
if [ $? -ne 0 ]; then
	cat "$CACHE_MMTESTS/$HASHDIR/cache.tmp"
	rm_hashdir
	exit -1
fi

gzip "$CACHE_MMTESTS/$HASHDIR/cache.tmp"
mv "$CACHE_MMTESTS/$HASHDIR/cache.tmp.gz" "$CACHE_MMTESTS/$HASHDIR/cache.gz"
zcat "$CACHE_MMTESTS/$HASHDIR/cache.gz"

if [ "$JSON_EXPORT" = "yes" -a -f "$MMTESTS_LOGDIR/$BENCHMARK.json.xz" ]; then
	mv "$MMTESTS_LOGDIR/$BENCHMARK.json.xz" "$CACHE_MMTESTS/$HASHDIR/cache.json.xz"
	ln -s "$CACHE_MMTESTS/$HASHDIR/cache.json.xz" "$MMTESTS_LOGDIR/$BENCHMARK.json.xz"
fi

# Cache tests-timestamp md5sums
if [ "$MMTESTS_LOGDIR" != "" ]; then
	cd $MMTESTS_LOGDIR
	for FILE in `ls */iter-*/tests-timestamp`; do
		mkdir -p $(dirname "$CACHE_MMTESTS/$HASHDIR/$FILE")
		cat $FILE | md5sum | awk '{print $1}' > "$CACHE_MMTESTS/$HASHDIR/$FILE"
	done
fi

unlock_hashdir
exit 0
