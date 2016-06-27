#!/bin/bash
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME/.." && pwd`
FAILED=no
P="run-single-test"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
if [ -n "$MMTEST_ITERATION" ]; then
	export SHELLPACK_LOG="$SHELLPACK_LOG/$MMTEST_ITERATION"
fi

if [ "$MMTESTS" = "" ]; then
	. $SCRIPTDIR/config
fi

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
if [ "$RUN_FINEPROFILE" = "yes" ]; then
	if [ "$FINEGRAINED_SUPPORTED" = "no" ]; then
		RUN_FINEPROFILE=no
		RUN_COARSEPROFILE=yes
	fi
fi

# Check that server/client execution is supported if requested
if [ "$REMOTE_SERVER_HOST" != "" ]; then
	if [ "$SERVER_SIDE_SUPPORT" != "yes" ]; then
		die Execution requested on server side but $NAME does not support it
		exit $SHELLPACK_ERROR
	fi
	if [ "$SERVER_SIDE_BENCH_SCRIPT" = "" ]; then
		SERVER_SIDE_BENCH_SCRIPT="shellpacks/shellpack-bench-$NAME"
	fi
	export REMOTE_SERVER_WRAPPER=$SCRIPTDIR/bin/config-wrap.sh
	export REMOTE_SERVER_SCRIPT=$SCRIPTDIR/$SERVER_SIDE_BENCH_SCRIPT
	mmtests_server_init
fi

function setup_dirs() {
	for DIRNAME in $SHELLPACK_TEMP $SHELLPACK_SOURCES $SHELLPACK_LOG; do
		if [ ! -e "$DIRNAME" ]; then
			mkdir -p "$DIRNAME"
		fi
	done
}

# no-profile run
if [ "$RUN_NOPROFILE" = "yes" ]; then
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
	save_rc run_bench 2>&1 | tee /tmp/mmtests-$$.log
	mv /tmp/mmtests-$$.log $LOGDIR_RESULTS/mmtests.log
	recover_rc
	check_status $NAME "returned failure, unable to continue"
	gzip $LOGDIR_RESULTS/mmtests.log
fi
fi

# Fine-grained profile
for PROFILE_HOOK in `ls $PROFILE_PATH/profile-hooks-*.sh 2> /dev/null`; do
. $PROFILE_HOOK
echo Processing profile hook $PROFILE_HOOK title $PROFILE_TITLE
if [ "$PROFILE_TITLE" = "none" ]; then
	continue
fi

if [ "$RUN_FINEPROFILE" = "yes" ]; then
export MONITOR_PRE_HOOK=`pwd`/monitor-pre-hook
export MONITOR_POST_HOOK=`pwd`/monitor-post-hook
export MONITOR_CLEANUP_HOOK=`pwd`/monitor-cleanup-hook
if [ -e fine-profile-$PROFILE_TITLE ]; then
	echo Fine-grained profile run already exists
else
	mkdir fine-profile-$PROFILE_TITLE
	export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/fine-profile-$PROFILE_TITLE

	setup_dirs
	save_rc run_bench 2>&1 | tee /tmp/mmtests-$$.log
	mv /tmp/mmtests-$$.log $LOGDIR_RESULTS/mmtests.log
	./monitor-reset
	recover_rc
	check_status $NAME "returned failure, unable to continue"
fi
fi

# Fine-grained profile
if [ "$RUN_COARSEPROFILE" = "yes" ]; then
for PROFILE_HOOK in `ls $PROFILE_PATH/profile-hooks-*.sh 2> /dev/null`; do
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
	save_rc run_bench 2>&1 | tee /tmp/mmtests-$$.log
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
