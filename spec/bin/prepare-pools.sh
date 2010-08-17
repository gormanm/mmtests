#!/bin/bash
MOUNTROOT=/var/lib/hugetlbfs/mounts

MEMTOTAL_KBYTES=`grep ^MemTotal /proc/meminfo | awk '{print $2}'`
MEMTOTAL_BYTES=$(($MEMTOTAL_KBYTES*1024))

# Make sure we have the utilities
which hugeadm > /dev/null || ( echo No hugeadm utility ; exit -1 )
which pagesize > /dev/null || ( echo No pagesize utility ; exit -1 )

# hugeadm helper
set_pagepool() {
	WHICH=$1
	PAGESIZE=$2
	PAGES=$3
	HARD=

	if [ "$WHICH" = "min" ]; then
		HARD=--hard
	fi

	hugeadm $HARD --pool-pages-$WHICH $PAGESIZE:$PAGES || exit -1

	if [ "$WHICH" = "min" ]; then
		ACTUAL=`hugeadm --pool-list | grep $PAGESIZE | awk '{print $2}'`
	else
		ACTUAL=`hugeadm --pool-list | grep $PAGESIZE | awk '{print $4}'`
	fi
	if [ $ACTUAL -lt $PAGES ]; then
		echo Requested $PAGES for pagesize $PAGESIZE, got $ACTUAL
		exit -1
	fi
	if [ $PAGES -ne 0 ]; then
		echo Set $WHICH poolsize for $PAGESIZE to $PAGES
	fi
}

# Configure pools
# For pagesizes < 1MB, dynamic resize up to memory total
# For pagesizes > 256MB, dynamic resize up to memory total
# For all others, 128MB statically, dynamic resize up to memory total
for PAGESIZE in `/usr/bin/pagesize -H`; do
	if [ $PAGESIZE -lt 1048576 ]; then
		set_pagepool min $PAGESIZE 0
		set_pagepool max $PAGESIZE $(($MEMTOTAL_BYTES/$PAGESIZE))
		continue
	fi

	if [ $PAGESIZE -gt $((1048576*256)) ]; then
		set_pagepool min $PAGESIZE 0
		set_pagepool max $PAGESIZE $(($MEMTOTAL_BYTES/$PAGESIZE))
	fi

	set_pagepool min $PAGESIZE $((1048576*128/$PAGESIZE))
	set_pagepool max $PAGESIZE $(($MEMTOTAL_BYTES/$PAGESIZE))
done

hugeadm --pool-list
