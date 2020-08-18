#!/bin/bash
set ${MMTESTS_SH_DEBUG:-+x}

DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME/.." && pwd`
P="update-build-flags.sh"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

if [ "$MMTESTS" = "" ]; then
	. $SCRIPTDIR/config
fi

if [ "$MMTESTS_BUILD_COLLECTION" = "" ]; then
	die "MMTESTS_BUILD_COLLECTION must be specified in shellpacks/common-config.sh"
fi

cd $SCRIPTDIR
if [ ! -e configs/build-flags ]; then
	git clone $MMTESTS_BUILD_COLLECTION configs/build-flags || \
		die "Failed to clone build-flags repository"
fi

git -C configs/build-flags remote update ||
	die "Failed to remote update build-flags repository"

git -C configs/build-flags checkout origin/master ||
	die "Failed to checkout origin/master"

echo build-flags updated
