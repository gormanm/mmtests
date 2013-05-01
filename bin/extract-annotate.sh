#!/bin/bash

if [ "$1" = "" ]; then
	echo Specify an oprofile report from mmtests
	exit -1
fi

grep -A 9999999 "=== annotate ===" "$1" | grep -v annotate | recode /b64..char | gunzip -c
