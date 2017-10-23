#!/bin/bash
# systemtap breaks almost constantly. This script tries to bodge it into
# working if possible

SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`/..
STAP_FILES="/usr/share/systemtap/runtime/linux/print.c
	    /usr/share/systemtap/runtime/linux/access_process_vm.h
	    /usr/share/systemtap/runtime/linux/runtime_defines.h
	    /usr/share/systemtap/transport/transport.c
	    /usr/share/systemtap/runtime/transport/transport.c
	    /usr/share/systemtap/runtime/stp_utrace.c
	    /usr/share/systemtap/runtime/transport/relay_v2.c"
if [ "`whoami`" != "root" ]; then
	exit
fi

backup_systemtap() {
	for STAP_FILE in $STAP_FILES; do
		if [ ! -e $STAP_FILE.orig ]; then
			cp $STAP_FILE $STAP_FILE.orig 2> /dev/null
		fi
	done
}

restore_systemtap() {
	for STAP_FILE in $STAP_FILES; do
		if [ -e $STAP_FILE.orig ]; then
			cp $STAP_FILE.orig $STAP_FILE 2> /dev/null
		fi
	done
}

# Check if stap is already working unless the script has been asked to
# restore stap to its original state
if [ "$1" != "--restore-only" ]; then
	stap -e 'probe begin { println("validate systemtap") exit () }'
	if [ $? == 0 ]; then
		exit 0
	fi
fi

# Backup original stap files before adjusting
backup_systemtap

# Restore original files and go through workarounds in order
restore_systemtap

if [ "$1" == "--restore-only" ]; then
	exit 0
fi
	
stap -e 'probe begin { println("validate systemtap") exit () }'
if [ $? == 0 ]; then
	exit 0
fi

echo WARNING: systemtap installation broken, trying to fix.

for PATCH in 4.5 4.6 4.6-rc3 4.7-rc1 4.8 4.9 4.10-rc2 4.10-rc4-next 4.11-rc5 4.14-rc4; do
	echo Applying patch systemtap-runtime-${PATCH}.patch
	cat $SCRIPTDIR/stap-patches/systemtap-runtime-${PATCH}.patch | patch -p1 -d /usr/share/systemtap
	if [ $? -ne 0 ]; then
		restore_systemtap
		echo ERROR: Unable to patch systemtap, upgrade to at least 3.0
		exit -1
	fi
	stap -e 'probe begin { println("validating systemtap fix") exit () }'
	if [ $? == 0 ]; then
		exit 0
	fi
done

# No other workarounds available
if [ "$STAP_FIX_LEAVE_BROKEN" != "yes" ]; then
	restore_systemtap
fi
exit -1
