#!/bin/bash
# This script assumes the existence of a lot of supporting scripts
DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
. $SCRIPTDIR/$CONFIG
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SHELLPACK_TOPLEVEL/kvm.conf

echo Booting kvm instance
kvm-start || die Failed to boot KVM instance
GUEST_IP=`kvm-ip-address`

echo Removing old mmtests
ssh root@$GUEST_IP rm -rf git-private/$NAME

echo Creating archive
NAME=`basename $SCRIPTDIR`
git archive --format=tar --prefix=$NAME/ `git rev-parse HEAD` | gzip -c - > ${NAME}.tar.gz
if [ $? -ne 0 ]; then
	die Failed to create mmtests archive
fi

echo Uploading and extracting new mmtests
scp ${NAME}.tar.gz root@$GUEST_IP: || die Failed to upload ${NAME}.tar.gz
ssh root@$GUEST_IP tar -C git-private -f ${NAME}.tar.gz || die Failed to extract ${NAME}.tar.gz

echo Booting current kernel `uname -r` on the guest
kvm-boot `uname -r` || die Failed to boot `uname -r`

echo Executing mmtests on the guest
ssh root@$GUEST_IP "cd git-private/$NAME && ./run-mmtests.sh $@"
RETVAL=$!

echo Syncing work/log
ssh root@$GUEST_IP "cd git-private/$NAME && tar -czf work.tar.gz work/log" || die Failed to archive work/log
scp root@$HOST_IP:git-private/$NAME/work.tar.gz .
tar -xf work.tar.gz

exit $RETVAL
