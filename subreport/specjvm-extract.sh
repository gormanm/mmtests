#!/bin/bash
# Extract SPEC results from a file

if [ "$1" = "" ]; then
	echo Specify a file to extract results from
	exit 1
fi

SRTLINE=`grep -n ^==== $1 | head -3 | tail -1 | cut -d: -f1`
ENDLINE=`grep -n "^Composite result" $1 | head -1 | cut -d: -f1`

if [ "$ENDLINE" = "" ]; then
	ENDLINE=`grep -n "^Noncompliant composite result" $1 | head -1 | cut -d: -f1`
fi

IFS="
"

# Aggregated results by class
if [ "$FINEGRAINED_ONLY" != "yes" ]; then
	X=1
	for RESULT in `head -$(($ENDLINE-1)) "$1" | tail -$(($ENDLINE-$SRTLINE-1)) | grep -v ^startup`; do
		echo $RESULT | awk "{print \$1\"	$X	\"(\$2 > 0 ? \$2 : 0)}"
		X=$(($X+1))
	done
fi

# Fine-grained results
SRTLINE=`grep -n ^------------- $1 | head -3 | tail -1 | cut -d: -f1`
ENDLINE=`grep -n "^SPECjvm2008 Version" $1 | head -1 | cut -d: -f1`
if [ "$COARSEGRAINED_ONLY" != "yes" ]; then
	X=1
	for RESULT in `head -$(($ENDLINE-1)) "$1" | tail -$(($ENDLINE-$SRTLINE-1)) | grep ^[a-z] | grep -v ^startup`; do
		echo $RESULT | awk "{print \$1\"-\"\$2\"	$X	\"(\$6 > 0 ? \$6 : 0)}"
		X=$(($X+1))
	done
fi
