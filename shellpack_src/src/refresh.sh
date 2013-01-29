#!/bin/bash

if [ "$1" = "" ]; then
	echo Specify package to refresh
	exit -1
fi

if [ ! -d $1 ]; then
	echo Package must be a directory
	exit -1
fi

if [ ! -d ../packs ]; then
	mkdir ../packs
fi

../bin/build-shellpack -s $1 -b $1-bench -i $1-install -o ../packs/shellpack-$1.tar.gz || exit -1
../bin/install-shellpack -p ../packs/shellpack-$1.tar.gz -i ../../shellpacks/ || exit -1

exit 0
