#!/bin/bash
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME/.." && pwd`
FAILED=no
P="run-single-test"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

if [ "$MMTESTS" = "" ]; then
	. $SCRIPTDIR/config
fi

function die() {
        echo "FATAL: $@"
        exit -1
}

setup_dirs

# Load the driver script
NAME=$1
if [ "$NAME" = "" ]; then
	echo Specify a test to run
	exit -1
fi
if [ -z "$SHELLPACK_LOG" ]; then
	echo "SHELLPACK_LOG has to be set"
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

NR_HOOKS=`ls $PROFILE_PATH/profile-hooks* 2> /dev/null | wc -l`
if [ $NR_HOOKS -gt 0 ]; then
	for PROFILE_HOOK in `ls $PROFILE_PATH/profile-hooks-*.sh 2> /dev/null`; do
		echo Processing profile hook $PROFILE_HOOK title $PROFILE_TITLE
		. $PROFILE_HOOK
	done

	export MONITOR_PRE_HOOK=`pwd`/monitor-pre-hook
	export MONITOR_POST_HOOK=`pwd`/monitor-post-hook
	export MONITOR_CLEANUP_HOOK=`pwd`/monitor-cleanup-hook
fi

export LOGDIR_RESULTS=$LOGDIR_TOPLEVEL/logs
mkdir logs
setup_dirs
save_rc run_bench 2>&1 | tee /tmp/mmtests-$$.log
mv /tmp/mmtests-$$.log $LOGDIR_RESULTS/mmtests.log
recover_rc
check_status $NAME "returned failure, unable to continue"
gzip $LOGDIR_RESULTS/mmtests.log

rm -rf $SHELLPACK_TEMP
exit $EXIT_CODE
