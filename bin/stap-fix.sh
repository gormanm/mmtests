#!/bin/bash
# systemtap breaks almost constantly. This script tries to bodge it into
# working if possible

SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`/..
STAP_FILES="/usr/share/systemtap/runtime/linux/print.c
	/usr/share/systemtap/runtime/linux/runtime_defines.h
	/usr/share/systemtap/runtime/stp_utrace.c"
if [ "`whoami`" != "root" ]; then
	exit
fi

# Check if stap is already working unless the script has been asked to
# restore stap to its original state
if [ "$1" != "--restore-only" ]; then
	stap -e 'probe begin { println("validate systemtap") exit () }'
	if [ $? == 0 ]; then
		exit 0
	fi
fi

# Backup original stap files before adjusting
for STAP_FILE in $STAP_FILES; do
	if [ -e $STAP_FILE -a ! -e $STAP_FILE.orig ]; then
		cp $STAP_FILE $STAP_FILE.orig 2> /dev/null
	fi
done

# Restore original files and go through workarounds in order
for STAP_FILE in $STAP_FILES; do
	cp $STAP_FILE.orig $STAP_FILE 2> /dev/null
done

if [ "$1" == "--restore-only" ]; then
	exit 0
fi
	
stap -e 'probe begin { println("validate systemtap") exit () }'
if [ $? == 0 ]; then
	exit 0
fi

echo WARNING: systemtap installation broken, trying to fix.
cat $SCRIPTDIR/stap-scripts/stap-runtime-1.patch | patch -p1 -d /usr/share/systemtap || exit -1
stap -e 'probe begin { println("validating systemtap fix") exit () }'
if [ $? == 0 ]; then
	exit 0
fi

# No other workarounds available
if [ "$STAP_FIX_LEAVE_BROKEN" != "yes" ]; then
	for STAP_FILE in $STAP_FILES; do
		if [ -e $STAP_FILE.orig ]; then
			mv $STAP_FILE.orig $STAP_FILE
		fi
	done
fi
exit -1
