#!/bin/bash
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
wget -O build-flags.tar.gz $MMTESTS_BUILD_COLLECTION
if [ $? -ne 0 ]; then
	rm -f build-flags.tar.gz
	die "Failed to download $MMTESTS_BUILD_COLLECTION"
fi
BACKUP=
if [ -e configs/build-flags ]; then
	DATESTAMP=`date -u +"%Y%m%d-%H:%M"`
	BACKUP="configs/build-flags-$DATESTAMP"
	mv configs/build-flags $BACKUP
	echo Backup old flags: $BACKUP
fi
tar -xf build-flags.tar.gz 
if [ $? -ne 0 ]; then
	if [ "$BACKUP" != "" ]; then
		echo Restoring $BACKUP
		mv $BACKUP configs/build-flags
	fi
	die "Failed to extract build-flags.sh"
fi
echo build-flags updated
