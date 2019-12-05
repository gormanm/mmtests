#!/bin/bash

DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
cd $SCRIPTDIR

if [ "$1" = "" ]; then
	echo Specify package to refresh
	exit -1
fi

if [ ! -d $1 ]; then
	echo Package must be a directory
	exit -1
fi

cat $1/$1-bench   | ../bin/rewrite-shellpack $1 > ../../shellpacks/shellpack-bench-$1
cat $1/$1-install | ../bin/rewrite-shellpack $1 > ../../shellpacks/shellpack-install-$1
chmod a+x ../../shellpacks/shellpack-bench-$1
chmod a+x ../../shellpacks/shellpack-install-$1

exit 0
