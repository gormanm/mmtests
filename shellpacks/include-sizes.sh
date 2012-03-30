##
# Return the word size in bytes
getwordsize() {
	if [ "$WORDSIZE" != "" ]; then
		return
	fi

	# Check if the pagesize is cached
	if [ -f "$SHELLPACK_TOPLEVEL/.wordsize" ]; then
		WORDSIZE=`cat "$SHELLPACK_TOPLEVEL/.wordsize"`
		return 0
	fi

	TEMPFILE=$SHELLPACK_TEMP/wordsize
	cat > $TEMPFILE.c << EOF
#include <stdio.h>
#include <stdlib.h>
int main() {
	printf("%d\n", sizeof(unsigned long));
	return 0;
}
EOF
	gcc $TEMPFILE.c -o $TEMPFILE || die Failed to compile wordsize program
	WORDSIZE=`$TEMPFILE` || die Failed to compile wordsize program
	echo $WORDSIZE > "$SHELLPACK_TOPLEVEL/.wordsize"
}

##
# Return the size of a double in bytes
getdoublesize() {
	if [ "$DOUBLESIZE" != "" ]; then
		return
	fi

	# Check if the pagesize is cached
	if [ -f "$SHELLPACK_TOPLEVEL/.doublesize" ]; then
		export DOUBLESIZE=`cat "$SHELLPACK_TOPLEVEL/.doublesize"`
		return 0
	fi

	TEMPFILE=$SHELLPACK_TEMP/doublesize
	cat > $TEMPFILE.c << EOF
#include <stdio.h>
#include <stdlib.h>
int main() {
	printf("%d\n", sizeof(double));
	return 0;
}
EOF
	gcc $TEMPFILE.c -o $TEMPFILE || die Failed to compile doublesize program
	export DOUBLESIZE=`$TEMPFILE` || die Failed to compile doublesize program
	echo $DOUBLESIZE > "$SHELLPACK_TOPLEVEL/.doublesize"
}

##
# Return the page size in bytes
getpagesize() {
	if [ "$PAGESIZE" != "" ]; then
		return
	fi

	# Check if the pagesize is cached
	if [ -f "$SHELLPACK_TOPLEVEL/.pagesize" ]; then
		export PAGESIZE=`cat "$SHELLPACK_TOPLEVEL/.pagesize"`
		return 0
	fi

	TEMPFILE=$SHELLPACK_TEMP/pagesize
	cat > $TEMPFILE.c << EOF
#include <stdio.h>
#include <stdlib.h>
int main() {
	printf("%d\n", getpagesize());
	return 0;
}
EOF
	gcc $TEMPFILE.c -o $TEMPFILE || die Failed to compile pagesize program
	export PAGESIZE=`$TEMPFILE` || die Failed to compile pagesize program
	echo $PAGESIZE > "$SHELLPACK_TOPLEVEL/.pagesize"
}

##
# Get the huge pagesize in bytes
gethugepagesize() {
	if [ "$HUGE_PAGESIZE" != "" ]; then
		return
	fi

	HUGE_PAGESIZE=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
	if [ "$HUGE_PAGESIZE" = "" ]; then
		echo WARNING: Hugepagesize not in /proc/meminfo. Assuming size of 4MB
		HUGE_PAGESIZE=$((4096))
	fi
	export HUGE_PAGESIZE=$(($HUGE_PAGESIZE*1024))
}

##
# Get the order of allocation required for a huge page
gethugetlb_order() {
	if [ "$HUGETLB_ORDER" != "" ]; then
		return
	fi

	gethugepagesize
	getpagesize
	NUM_SMALLPAGES=$(($HUGE_PAGESIZE/$PAGESIZE))
	export HUGETLB_ORDER=`perl -e "print log($NUM_SMALLPAGES)/log(2)"`
}

##
# Get memtotals
getmemtotals() {
	if [ "$MEMTOTAL_BYTES" != "" ]; then
		return
	fi
	getpagesize
	gethugepagesize
	export MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
	export MEMTOTAL_PAGES=$(($MEMTOTAL_BYTES/$PAGESIZE))
	export MEMTOTAL_HUGEPAGES=$(($MEMTOTAL_BYTES/$HUGE_PAGESIZE))
}
