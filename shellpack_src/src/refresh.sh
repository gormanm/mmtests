#!/bin/bash
set ${MMTESTS_SH_DEBUG:-+x}

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
if [ -e $1/$1-bench ]; then
	cp $1/$1-bench ../../shellpacks/shellpack-bench-$1
fi
if [ -e $1/$1-install ]; then
	cp $1/$1-install ../../shellpacks/shellpack-install-$1
fi

for STAGES in 1 2; do
	if [ -e ../../shellpacks/shellpack-bench-$1 ]; then
		cat ../../shellpacks/shellpack-bench-$1 | ../bin/rewrite-shellpack $1 > ../../shellpacks/shellpack-bench-$1.stage
		mv ../../shellpacks/shellpack-bench-$1.stage ../../shellpacks/shellpack-bench-$1
		chmod a+x ../../shellpacks/shellpack-bench-$1
	fi
	if [ -e ../../shellpacks/shellpack-install-$1 ]; then
		cat ../../shellpacks/shellpack-install-$1 | ../bin/rewrite-shellpack $1 > ../../shellpacks/shellpack-install-$1.stage
		mv ../../shellpacks/shellpack-install-$1.stage ../../shellpacks/shellpack-install-$1
		chmod a+x ../../shellpacks/shellpack-install-$1
	fi
done

exit 0
