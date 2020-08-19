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
for kind in bench install; do
    if [ -e ../../shellpacks/shellpack-$kind-$1 ]; then
	while cat ../../shellpacks/shellpack-$kind-$1 | ../bin/rewrite-shellpack $1 > ../../shellpacks/shellpack-$kind-$1.stage
	do
	    mv ../../shellpacks/shellpack-$kind-$1.stage ../../shellpacks/shellpack-$kind-$1
	done
	rm -f ../../shellpacks/shellpack-$kind-$1.stage
	chmod a+x ../../shellpacks/shellpack-$kind-$1
    fi
done

exit 0
