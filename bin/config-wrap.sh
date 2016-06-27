#!/bin/bash
# This is used specifically for executing shellpack files directly. This
# should almost never be executed by a user directly. It is intended for
# use by a client machine controlling a server
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME/.." && pwd`
P="config-wrap"
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh

if [ "$MMTESTS" = "" ]; then
	. $SCRIPTDIR/config
fi
eval $@
