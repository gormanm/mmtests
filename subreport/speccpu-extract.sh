#!/bin/bash
# Extract SPEC results from a file

if [ "$1" = "" ]; then
	echo Specify a file to extract results from
	exit 1
fi

TEST=`grep OMPM $1`
if [ "$TEST" != "" ]; then
	SPACERA="   "
	SPACERB="  "
fi

SRTLINE=`grep -n "^$SPACERA====" $1 | head -1 | cut -d: -f1`
ENDLINE=`grep -n "^$SPACERB Est. SPEC" $1 | head -1 | cut -d: -f1`

IFS="
"

X=1
for RESULT in `head -$(($ENDLINE-1)) "$1" | tail -$(($ENDLINE-$SRTLINE-1))`; do
	echo $RESULT | awk "{print \$1\"	$X	\"(\$4 > 0 ? \$4 : 0)\" \"(\$3 > 0 ? \$3 : 0)}"
	X=$(($X+1))
done
