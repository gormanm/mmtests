#!/bin/bash
# systemtap breaks almost constantly. This script tries to bodge it into
# working if possible

STAP_FILES="/usr/share/systemtap/runtime/stack.c /usr/share/systemtap/runtime/transport/relay_v2.c
	/usr/share/systemtap/runtime/transport/transport.c /usr/share/systemtap/runtime/stat.c
	/usr/share/systemtap/runtime/map.c /usr/share/systemtap/runtime/map-stat.c
	/usr/share/systemtap/runtime/task_finder2.c /usr/share/systemtap/runtime/task_finder_vma.c
	/usr/share/systemtap/runtime/linux/task_finder_map.c /usr/share/systemtap/runtime/linux/task_finder_map.c
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

# Adjust to removal of warning hook
sed /usr/share/systemtap/runtime/stack.c \
	-e 's/.warning = print_stack_warning/\/\/MMTESTS:.warning = print_stack_warning/' \
	-e 's/.warning_symbol = print_stack_warning_symbol,/\/\/MMTESTS:.warning_symbol = print_stack_warning_symbol,/' > /usr/share/systemtap/runtime/stack.c.tmp
mv /usr/share/systemtap/runtime/stack.c.tmp /usr/share/systemtap/runtime/stack.c
stap -e 'probe begin { println("validating systemtap fix") exit () }'
if [ $? == 0 ]; then
	exit 0
fi

# Mode changed type and a field rename
sed /usr/share/systemtap/runtime/transport/relay_v2.c \
	-e 's/int mode/umode_t mode/' > /usr/share/systemtap/runtime/transport/relay_v2.c.tmp
mv /usr/share/systemtap/runtime/transport/relay_v2.c.tmp /usr/share/systemtap/runtime/transport/relay_v2.c
sed /usr/share/systemtap/runtime/transport/transport.c \
	-e 's/fs_supers.next/fs_supers.first/' > /usr/share/systemtap/runtime/transport/transport.c.tmp
mv /usr/share/systemtap/runtime/transport/transport.c.tmp /usr/share/systemtap/runtime/transport/transport.c
stap -e 'probe begin { println("validating systemtap fix") exit () }'
if [ $? == 0 ]; then
	exit 0
fi

# Change in CPU iterators
for FILE in stat.c map-stat.c map.c; do
	sed /usr/share/systemtap/runtime/$FILE \
		-e 's/stp_for_each_cpu/for_each_online_cpu/' > /usr/share/systemtap/runtime/$FILE.tmp
	mv /usr/share/systemtap/runtime/$FILE.tmp /usr/share/systemtap/runtime/$FILE
done
stap -e 'probe begin { println("validating systemtap fix") exit () }'
if [ $? == 0 ]; then
	exit 0
fi

# Crude workaround for VMA flag change
sed /usr/share/systemtap/runtime/task_finder2.c \
	-e 's/VM_EXECUTABLE/0xF/' > /usr/share/systemtap/runtime/task_finder2.c.tmp
mv /usr/share/systemtap/runtime/task_finder2.c.tmp /usr/share/systemtap/runtime/task_finder2.c
stap -e 'probe begin { println("validating systemtap fix") exit () }'
if [ $? == 0 ]; then
	exit 0
fi

# Change in hlist API
if [ -e /usr/share/systemtap/runtime/task_finder_vma.c ]; then
	sed /usr/share/systemtap/runtime/task_finder_vma.c \
		-e 's/hlist_for_each_entry_safe(entry, node/hlist_for_each_entry_safe(entry/' \
		-e 's/hlist_for_each_entry(/hlist_for_each_entry_safe(/' > /usr/share/systemtap/runtime/task_finder_vma.c.tmp
	mv /usr/share/systemtap/runtime/task_finder_vma.c.tmp /usr/share/systemtap/runtime/task_finder_vma.c
fi
if [ -e /usr/share/systemtap/runtime/linux/task_finder_map.c ]; then
	sed /usr/share/systemtap/runtime/linux/task_finder_map.c \
		-e 's/hlist_for_each_entry(/hlist_for_each_entry_safe(/' > /usr/share/systemtap/runtime/linux/task_finder_map.c.tmp
	mv /usr/share/systemtap/runtime/linux/task_finder_map.c.tmp /usr/share/systemtap/runtime/linux/task_finder_map.c
fi
if [ -e /usr/share/systemtap/runtime/task_finder_map.c ]; then
	sed /usr/share/systemtap/runtime/task_finder_map.c \
		-e 's/hlist_for_each_entry(/hlist_for_each_entry_safe(/' > /usr/share/systemtap/runtime/task_finder_map.c.tmp
	mv /usr/share/systemtap/runtime/task_finder_map.c.tmp /usr/share/systemtap/runtime/task_finder_map.c
fi
sed /usr/share/systemtap/runtime/stp_utrace.c \
	-e 's/hlist_for_each_entry_safe(utrace, node/hlist_for_each_entry_safe(utrace/' \
	-e 's/hlist_for_each_entry(/hlist_for_each_entry_safe(/' > /usr/share/systemtap/runtime/stp_utrace.c.tmp
mv /usr/share/systemtap/runtime/stp_utrace.c.tmp /usr/share/systemtap/runtime/stp_utrace.c
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
