STARTING_HUGEPAGES=`cat /proc/sys/vm/nr_hugepages`
AVAILABLE_HUGEPAGES=`cat /proc/sys/vm/nr_hugepages`
MOUNTED_HUGETLBFS=no
HUGETLBFS_MNT=/hugetlbfs

##
# Create a TEMPFILE variable
gettempfile() {
	if [ "$TEMPFILE" != "" ]; then
		rm "$TEMPFILE*" 2> /dev/null
	fi
	export TEMPFILE=`mktemp`
	if [ "$TEMPFILE" = "" ]; then
		export TEMPFILE=`mktemp -t mmtests.XXXXXX`
		if [ "$TEMPFILE" = "" ]; then
			echo Warning: Not sure how to use mktemp. Bodging
			TEMPFILE=/tmp/mmtests.`date +%s`
		fi
	fi

}

##
# Return the page size in bytes
getpagesize() {
	if [ "$PAGESIZE" != "" ]; then
		return
	fi

	# Check if the pagesize is cached
	if [ -f "$HOME/.pagesize" ]; then
		export PAGESIZE=`cat "$HOME/.pagesize"`
		return 0
	fi

	gettempfile
	cat > $TEMPFILE.c << EOF
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main() {
       printf("%d\n", getpagesize());
       return 0;
}
EOF
	gcc $TEMPFILE.c -o $TEMPFILE || die Failed to compile pagesize program
	export PAGESIZE=`$TEMPFILE` || die Failed to compile pagesize program
	echo $PAGESIZE > "$HOME/.pagesize"
}


##
# Return the word size in bytes
getwordsize() {
	if [ "$WORDSIZE" != "" ]; then
		return
	fi

	# Check if the pagesize is cached
	if [ -f "$HOME/.wordsize" ]; then
		export WORDSIZE=`cat "$HOME/.wordsize"`
		return 0
	fi

	gettempfile
	cat > $TEMPFILE.c << EOF
#include <stdio.h>
#include <stdlib.h>
int main() {
	printf("%d\n", sizeof(unsigned long));
	return 0;
}
EOF
	gcc $TEMPFILE.c -o $TEMPFILE || die Failed to compile wordsize program
	export WORDSIZE=`$TEMPFILE` || die Failed to compile wordsize program
	echo $WORDSIZE > "$HOME/.wordsize"
}

##
# Return the size of a double in bytes
getdoublesize() {
	if [ "$DOUBLESIZE" != "" ]; then
		return
	fi

	# Check if the pagesize is cached
	if [ -f "$HOME/.doublesize" ]; then
		export DOUBLESIZE=`cat "$HOME/.doublesize"`
		return 0
	fi

	gettempfile
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
	echo $DOUBLESIZE > "$HOME/.doublesize"
}

##
# Get the huge pagesize in bytes
gethugepagesize() {
	if [ "$HUGE_PAGESIZE" != "" ]; then
		return
	fi

	HUGE_PAGESIZE=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
	if [ "$HUGE_PAGESIZE" = "" ]; then
		echo WARNING: Hugepagesize not in /proc/meminfo. Assuming size 
		HUGE_PAGESIZE=4096
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
	HUGETLB_ORDER=`perl -e "print log($NUM_SMALLPAGES)/log(2)"`
}

reserve_hugepages() {
	if [ "$1" = "--use-dynamic-pool" ]; then
		DYNAMIC_RESIZE=yes
		shift
	fi
	REQUIRED_PAGES=$1

	# Guess where the 64-bit version is
	LIBHUGETLBFS64_LIB=`echo $LIBHUGETLBFS_LIB | sed -e 's/\/lib\//\/lib64\//'`

	# Ensure hugepages are supported
	if [ ! -e /proc/sys/vm/nr_hugepages ]; then
		echo ERROR: hugepages do not appear to be supported
		exit 1
	fi

	# Mount hugetlbfs if necessary
	TEST=`mount | grep "type hugetlbfs"`
	if [ "$TEST" = "" ]; then
		mkdir -p $HUGETLBFS_MNT
		if [ ! -d $HUGETLBFS_MNT ]; then
			echo ERROR: Unable to create hugetlbfs mount point
			exit 1
		fi
		chmod a+rwx $HUGETLBFS_MNT
		mount -t hugetlbfs none $HUGETLBFS_MNT || exit 1
		chmod a+rwx $HUGETLBFS_MNT
		export MOUNTED_HUGETLBFS=yes
	fi

	# Reserve the number of hugepages required for the test
	ATTEMPT=0
	echo $REQUIRED_PAGES > /proc/sys/vm/nr_hugepages || die Failed to write to /proc/sys/vm/nr_hugepages
	while [ `cat /proc/sys/vm/nr_hugepages` -ne $REQUIRED_PAGES -a $ATTEMPT -lt 40 ]; do
		ATTEMPT=$(($ATTEMPT+1))
		echo Hugepage reserve attempt $ATTEMPT: `cat /proc/sys/vm/nr_hugepages` of $REQUIRED_PAGES
		sleep 2
		echo 0 > /proc/sys/vm/drop_caches
		echo 1 > /proc/sys/vm/drop_caches
		echo 2 > /proc/sys/vm/drop_caches
		echo $REQUIRED_PAGES > /proc/sys/vm/nr_hugepages
	done
	AVAILABLE_HUGEPAGES=`cat /proc/sys/vm/nr_hugepages`

	if [ "$USE_DYNAMIC_HUGEPAGES" = "yes" ]; then
		echo Reconfiguring for dynamic hugepages
		echo $REQUIRED_HUGEPAGES > /proc/sys/vm/nr_overcommit_hugepages
		echo 0 > /proc/sys/vm/nr_hugepages
	fi
}

reset_hugepages() {
	echo $STARTING_HUGEPAGES 2> /dev/null > /proc/sys/vm/nr_hugepages
	if [ "$MOUNTED_HUGETLBFS" = "yes" ]; then
		umount "$HUGETLBFS_MNT"
		rmdir "$HUGETLBFS_MNT"
	fi
}
