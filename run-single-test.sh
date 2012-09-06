#!/bin/bash
DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
FAILED=no
P="run-single-test"
. $SCRIPTDIR/config
. $SHELLPACK_INCLUDE/common.sh

function die() {
        echo "FATAL: $@"
        exit -1
}

for DIRNAME in $SHELLPACK_TEMP $SHELLPACK_SOURCES $SHELLPACK_LOG; do
	if [ ! -e "$DIRNAME" ]; then
		mkdir -p "$DIRNAME"
	fi
done

# Load the driver script
NAME=$1
if [ "$NAME" = "" ]; then
	echo Specify a test to run
	exit -1
fi
if [ ! -e $SCRIPTDIR/drivers/driver-$NAME.sh ]; then
	echo A driver script called driver-$NAME.sh does not exist
fi
shift
. $SCRIPTDIR/drivers/driver-$NAME.sh

# Logging parameters
export LOGDIR_TOPLEVEL=$SHELLPACK_LOG/$NAME$NAMEEXTRA
rm -rf $SHELLPACK_LOG/$NAME$NAMEEXTRA
mkdir -p $LOGDIR_TOPLEVEL
cd $LOGDIR_TOPLEVEL

# Force the running of a coarse-grained profile if a fine-grained
# profile is requested but the underlying test does not support
# the necessary hooks
if [ "$SKIP_FINEPROFILE" != "yes" ]; then
	if [ "$FINEGRAINED_SUPPORTED" = "no" ]; then
		SKIP_FINEPROFILE=yes
		SKIP_COARSEPROFILE=no
	fi
fi

# Check should be unecessary because of run-mmtests but conceivably someone
# would run this script directly so ....
if [ "$SKIP_FINEPROFILE" = "no" -o "$SKIP_COARSEPROFILE" = "no" ]; then
	if [ "`which oprofile_start.sh`" = "" ]; then
		$SHELLPACK_TOPLEVEL/shellpacks/shellpack-install-libhugetlbfsbuild -v 2.9
		export PATH=$SHELLPACK_SOURCES/libhugetlbfs-2.9-installed/bin:$PATH
		if [ "`which oprofile_start.sh`" = "" ]; then
			echo ERROR: Profiling requested but unable to provide
			echo -1
		fi
	fi
fi

function setup_dirs() {
	for DIRNAME in $SHELLPACK_TEMP $SHELLPACK_SOURCES $SHELLPACK_LOG; do
		if [ ! -e "$DIRNAME" ]; then
			mkdir -p "$DIRNAME"
		fi
	done
}

# no-profile run
if [ "$SKIP_NOPROFILE" != "yes" ]; then
unset PROFILE_EVENTS
unset MONITOR_PRE_HOOK
unset MONITOR_POST_HOOK
unset MONITOR_CLEANUP_HOOK
if [ -e noprofile ]; then
	echo No profile run already exists
else
	mkdir noprofile
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/noprofile

	setup_dirs
	save_rc run_bench | tee /tmp/mmtests-$$.log
	mv /tmp/mmtests-$$.log $LOGDIR_RESULTS/mmtests.log
	recover_rc
	check_status $NAME "returned failure, unable to continue"
fi
fi

# Fine-grained profile
for PROFILE_HOOK in `ls $PROFILE_PATH/profile-hooks-*.sh`; do
. $PROFILE_HOOK
echo Processing profile hook $PROFILE_HOOK title $PROFILE_TITLE
if [ "$PROFILE_TITLE" = "none" ]; then
	continue
fi

if [ "$SKIP_FINEPROFILE" != "yes" ]; then
export MONITOR_PRE_HOOK=`pwd`/monitor-pre-hook
export MONITOR_POST_HOOK=`pwd`/monitor-post-hook
export MONITOR_CLEANUP_HOOK=`pwd`/monitor-cleanup-hook
if [ -e fine-profile-$PROFILE_TITLE ]; then
	echo Fine-grained profile run already exists
else
	mkdir fine-profile-$PROFILE_TITLE
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/fine-profile-$PROFILE_TITLE

	setup_dirs
	save_rc run_bench | tee /tmp/mmtests-$$.log
	mv /tmp/mmtests-$$.log $LOGDIR_RESULTS/mmtests.log
	./monitor-reset
	recover_rc
	check_status $NAME "returned failure, unable to continue"
fi
fi

# Fine-grained profile
if [ "$SKIP_COARSEPROFILE" != "yes" ]; then
for PROFILE_HOOK in `ls $PROFILE_PATH/profile-hooks-*.sh`; do
. $PROFILE_HOOK
echo Processing profile hook $PROFILE_HOOK title $PROFILE_TITLE
if [ "$PROFILE_TITLE" = "none" ]; then
	continue
fi

unset MONITOR_PRE_HOOK
unset MONITOR_POST_HOOK
unset MONITOR_CLEANUP_HOOK
unset PROFILE_EVENTS
if [ -e coarse-profile-$PROFILE_TITLE ]; then
	echo Global profile run already exists
else
	mkdir coarse-profile-$PROFILE_TITLE
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/coarse-profile-$PROFILE_TITLE

	setup_dirs
	./monitor-pre-hook || die Failed to start profiler
	save_rc run_bench | tee /tmp/mmtests-$$.log
	mv /tmp/mmtests-$$.log $LOGDIR_RESULTS/mmtests.log
	./monitor-post-hook $LOGDIR_RESULTS $NAME || die Failed to stop profiler
	./monitor-reset
	recover_rc
	check_status $NAME "returned failure, unable to continue"
fi
done
fi
done

rm -rf $SHELLPACK_TEMP
