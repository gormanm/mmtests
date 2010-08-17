#!/bin/bash
export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
source $SCRIPTDIR/lib/sh/funcs.sh

getpagesize             # Sets PAGESIZE
gethugepagesize         # Sets HUGE_PAGESIZE
gethugetlb_order        # Sets HUGETLB_ORDER
getmemtotals            # Sets MEMTOTAL_BYTES and MEMTOTAL_PAGES

MAXPAGES=$(($MEMTOTAL_BYTES/$HUGE_PAGESIZE*4/5))
START=`cat /proc/sys/vm/nr_hugepages`
CURRENT=`cat /proc/sys/vm/nr_hugepages`
ATTEMPT=1

while [ $CURRENT -ne $MAXPAGES -a $ATTEMPT -lt 10 ]; do
	echo $MAXPAGES > /proc/sys/vm/nr_hugepages
	CURRENT=`cat /proc/sys/vm/nr_hugepages`
	ATTEMPT=$(($ATTEMPT+1))
done

echo $START > /proc/sys/vm/nr_hugepages
