#!/bin/bash

DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
ARCH=`uname -m`

. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
cd $SHELLPACK_TOPLEVEL

setup_dirs

mkdir -p $SHELLPACK_TOPLEVEL/prebuilds/$ARCH/

for PACKAGE in ffsb fsmark hackbench lmbench memcached memcachetest netperf pft pipetest postgresbuild postmark starve sysbench; do
	# Check if we already built it
	if [ -e $SHELLPACK_TOPLEVEL/prebuilds/$ARCH/$PACKAGE.tar.gz ]; then
		echo Already built $PACKAGE for arch $ARCH
		continue
	fi

	if [ "$PACKAGE" = "postgresbuild" -o "$PACKAGE" = "sysbench" ]; then
		if [ "`whoami`" != "root" ]; then
			echo root required to build package $PACKAGE
			continue
		fi
	fi

	# Clean out the sources directory and build this package
	rm -rf $SHELLPACK_SOURCES/*
	echo Prebuilding $PACKAGE for arch $ARCH
	$SHELLPACK_TOPLEVEL/prebuild-mmtest.sh $PACKAGE > $SHELLPACK_TEMP/build.log 2>&1
	if [ $? -ne 0 ]; then
		cat $SHELLPACK_TEMP/build.log
		echo BUILD FAILED FOR PACKAGE $PACKAGE ARCH $ARCH
		echo Build log: $SHELLPACK_TEMP/build.log
		exit $SHELLPACK_ERROR
	fi

	echo Creating $SHELLPACK_TOPLEVEL/prebuilds/$ARCH/$PACKAGE.tar.gz
	tar -czf $SHELLPACK_TOPLEVEL/prebuilds/$ARCH/$PACKAGE.tar.gz work/testdisk/sources/*-installed 2> /dev/null
done

# Build different versions of dbench
for VERSION in 3.04 4.0; do
	# Check if we already built it
	if [ -e $SHELLPACK_TOPLEVEL/prebuilds/$ARCH/dbench$VERSION.tar.gz ]; then
		echo Already built dbench$VERSION for arch $ARCH
		continue
	fi

	# Clean out the sources directory and build this package
	rm -rf $SHELLPACK_SOURCES/*
	echo Prebuilding dbench$VERSION for arch $ARCH
	$SHELLPACK_TOPLEVEL/prebuild-mmtest.sh dbench -v $VERSION > $SHELLPACK_TEMP/build.log 2>&1
	if [ $? -ne 0 ]; then
		cat $SHELLPACK_TEMP/build.log
		echo BUILD FAILED FOR PACKAGE dbench$VERSION ARCH $ARCH
		echo Build log: $SHELLPACK_TEMP/build.log
		exit $SHELLPACK_ERROR
	fi

	echo Creating $SHELLPACK_TOPLEVEL/prebuilds/$ARCH/dbench$VERSION.tar.gz
	tar -czf $SHELLPACK_TOPLEVEL/prebuilds/$ARCH/dbench$VERSION.tar.gz work/testdisk/sources/*-installed 2> /dev/null
done
rm -rf $SHELLPACK_TEMP
exit $SHELLPACK_SUCCESS
