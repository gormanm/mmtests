#!/bin/bash

# Paths for results directory and the like
export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
source $SCRIPTDIR/lib/sh/funcs.sh
export PATH=$PATH:$SCRIPTDIR

RESULT_DIR=$HOME/vmregressbench-`uname -r`/stream
EXTRA=
SOURCE=http://www.cs.virginia.edu/stream/FTP/Code/
TLANG=c
LINK_OPTIONS=-O2
if [ "$STREAM_ITERATIONS" != "" ]; then
	INSTANCES=$STREAM_ITERATIONS
else
	INSTANCES=10
fi
MINIMUM_POWER=17
LARGEST_POWER=29
INCREMENT=3
HUGECTL=

case `uname -m` in
	i?86)
		LARGEST_POWER=29
		LINK_OPTIONS="$LINK_OPTIONS -m32"
		;;
	*)
		LARGEST_POWER=31
		LINK_OPTIONS="$LINK_OPTIONS -m64"
		;;
esac

# Get path to stream root
STREAM_ROOT=`echo $0 | sed -e 's/\/bench-stream.sh//'`/../scratch/
if [ ! -e $STREAM_ROOT ]; then
	mkdir -p $STREAM_ROOT
fi
pushd $STREAM_ROOT > /dev/null
STREAM_ROOT=`pwd`/stream
popd > /dev/null

# Adjust LARGEST_POWER to memory
MEMTOTAL_BYTES=`free -b | grep Mem: | awk '{print $2}'`
LARGEST_ARRAY=$((1<<$LARGEST_POWER))
while [ $LARGEST_ARRAY -gt $MEMTOTAL_BYTES ]; do
	LARGEST_POWER=$(($LARGEST_POWER-1))
	LARGEST_ARRAY=$((1<<$LARGEST_POWER))
done

# Print usage of command
usage() {
	echo "bench-stream.sh (c) Mel Gorman 2005"
	echo This script is a wrapper around the stream \(http://www.cs.virginia.edu/stream\)
	echo benchmark. 
	echo
	echo "Usage: bench-stream.sh [options]"
	echo "        --lang-c                   Run the C benchmark (default)"
	echo "        --lang-fortran             Run the fortran benchmark"
	echo "        --libhugetlbfs-root    <path> Root to libhugetlbfs"
	echo "        --libhugetlbfs-libpath <path> Library Path to libhugetlbfs.so"
	echo "        --libhugetlbfs-ld <path>   Path to ld symbolic link to ld.hugetlbfs"
	echo "        --use-static-array         Use a statically allocated array (default)"
	echo "        --use-malloc-array         Allocate the array with malloc()"
	echo "        --use-stack-array          Allocate the array on the stack()"
	echo "        --use-gh_page              Use 1 x get_huge_pages()"
	echo "        --use-3gh_page	         Use 3 x get_huge_pages()"
	echo "        --use-gh_region            Use get_hugepage_region()"
	echo "        --use-3gh_region           Use get_hugepage_region()"
	echo "        --use-libhugetlbfs-stack   Back stack with large pages"
	echo "        --use-libhugetlbfs-malloc  Back malloc with large pages"
	echo "        --use-libhugetlbfs-b       Back BSS with large pages"
	echo "        --use-libhugetlbfs-bdt     Back BSS, Data and Text with large pages"
	echo "        --use-libhugetlbfs-align   Back BSS, Data and Text with large pages"
	echo "        --no-check-deviation       What it says on the tin"
	echo "        --increments               Increments to use between powers"
	echo "        -m, --max-powers           The highest power of two used for WSS"
	echo "        -e, --extra NAME           Extra name to tag onto the title"
	echo "        -r, --result               Result directory (default: $RESULT_DIR)"
	echo "        -h, --help                 Print this help message"
	echo

	exit
}

# Parse command line arguements
ARGS=`getopt -o he:r:m: --long help,lang-c,lang-fortran,use-libhugetlbfs,use-libhugetlbfs-stack,use-libhugetlbfs-malloc,use-libhugetlbfs-b,use-libhugetlbfs-bdt,use-libhugetlbfs-align,libhugetlbfs-root:,libhugetlbfs-libpath:,libhugetlbfs-ld:,max-powers:,use-static-array,use-gh_page,use-3gh_page,no-check-deviation,use-gh_region,use-3gh_region,use-stack-array,use-malloc-array,extra:result:,increments: -n bench-stream.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
	case "$1" in
	--lang-c)			TLANG=c; shift;;
	--lang-fortran)			TLANG=f; shift;;
	--use-libhugetlbfs)		usage;;
	--libhugetlbfs-root)		LIBHUGETLBFS_ROOT=$2
					shift 2;;
	--libhugetlbfs-libpath)		LIBHUGETLBFS_LIBPATH=$2
					shift 2;;
	--libhugetlbfs-ld)	 	LIBHUGETLBFS_LD=$2; shift 2;;
	--use-static-array)		ARRAY=static; shift;;
	--use-malloc-array)		ARRAY=malloc; shift;;
	--use-stack-array)		ARRAY=stack
					ulimit -s $((512*1048576))
					shift;;
	--use-gh_page)
					ARRAY=gh_page
					shift;;
	--use-3gh_page)
					ARRAY=3gh_page
					shift;;
	--use-gh_region)
					ARRAY=gh_region
					shift;;
	--use-3gh_region)
					ARRAY=3gh_region
					shift;;

	--use-libhugetlbfs-stack) 	HUGETLBFS_STACK=yes
					ARRAY=stack
					shift;;
	--use-libhugetlbfs-malloc) 	HUGETLBFS_MALLOC=yes
					ARRAY=malloc
					shift;;
	--use-libhugetlbfs-bdt)		HUGETLBFS_BDT=BDT; shift;;
	--use-libhugetlbfs-b)		HUGETLBFS_BDT=B; shift;;
	--use-libhugetlbfs-align)	HUGETLBFS_BDT=align; shift;;
	--no-check-deviation)		NOCHECK_DEVIATION=yes; shift;;
	--increments)			INCREMENT=$2; shift 2;;
	-m|--max-powers)		parse_max_powers $2
					shift 2;;
	-e|--extra)			EXTRA=$2; shift 2;;
	-r|--result)			RESULT_DIR="$2"; shift 2;;
	-h|--help) usage;;
	--) break;;
				*) echo Unrecognised switch: $1; exit;;
	esac
done

if [ "$LIBHUGETLBFS_LIBPATH" = "" ]; then
	LIBHUGETLBFS_LIBPATH=$LIBHUGETLBFS_ROOT/lib:$LIBHUGETLBFS_ROOT/lib64
fi
if [ "$LIBHUGETLBFS_LD" = "" ]; then
	LIBHUGETLBFS_LD=$LIBHUGETLBFS_ROOT/share/libhugetlbfs
fi
export PATH=$LIBHUGETLBFS_ROOT/bin:$PATH
HUGECTL="`which hugectl 2> /dev/null`"
if [ "$HUGECTL" = "" ]; then
	die "hugectl must be in your PATH to use --use-stack-array"
fi

RESULT_DIR="$RESULT_DIR$EXTRA"

# Setup basic steam
mkdir -p $STREAM_ROOT
cd $STREAM_ROOT || die Failed to setup stream root
if [ ! -f stream.c ]; then
	echo Downloading stream
	wget -nv $SOURCE/stream.c -O stream.c || die Failed to download stream.c
	wget -nv $SOURCE/stream.f -O stream.f || die Failed to download stream.f
	wget -nv $SOURCE/mysecond.c -O mysecond.c || die Failed to download mysecond.c
fi

# Setup results directory
RESULTS=$RESULT_DIR/log.txt
if [ -e $RESULT_DIR ]; then
	die Results directory \($RESULT_DIR\) already exists
fi
mkdir -p $RESULT_DIR
RESULT="$RESULT_DIR/log.txt"

# START BENCHMARK
echo Starting stream benchmark | tee $RESULT

# Copy in the original source
mkdir $RESULT_DIR/stream_src
cp $STREAM_ROOT/* $RESULT_DIR/stream_src || die Failed to copy stream code
cd $RESULT_DIR/stream_src || die Failed to change directory to stream code

# Patch for one call to get_huge_pages
if [ "$ARRAY" = "gh_page" ]; then
	if [ "$TLANG" != "c" ]; then
		die "Option --use-gh_page depends on --lang-c"
	fi
	echo Patching stream for 1 call to get_huge_pages | tee -a $RESULTS
	echo '--- stream.c	2007-03-27 13:28:59.000000000 +0100
+++ stream-gh_page.c	2008-11-04 15:15:17.000000000 +0000
@@ -45,6 +45,8 @@
 # include <float.h>
 # include <limits.h>
 # include <sys/time.h>
+# include <stdlib.h>
+# include <hugetlbfs.h>
 
 /* INSTRUCTIONS:
  *
@@ -88,9 +92,7 @@
 # define MAX(x,y) ((x)>(y)?(x):(y))
 # endif
 
-static double	a[N+OFFSET],
-		b[N+OFFSET],
-		c[N+OFFSET];
+static double	*a, *b, *c;
 
 static double	avgtime[4] = {0}, maxtime[4] = {0},
 		mintime[4] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX};
@@ -125,13 +127,22 @@
     double		scalar, t, times[4][NTIMES];
 
     /* --- SETUP --- determine precision and check timing --- */
-
+    size_t len = sizeof(double) * (N + OFFSET) * 3;
+    len = (len + gethugepagesize() - 1) & ~(gethugepagesize()-1);
+    a = get_huge_pages(len, GHP_DEFAULT);
+    b = a + N + OFFSET;
+    c = b + N + OFFSET;
+    if (a == NULL) {
+        printf("Failed to alloc arrays\n");
+        exit(-1);
+    }
     printf(HLINE);
     printf("STREAM version $Revision: 5.9 $\n");
     printf(HLINE);
     BytesPerWord = sizeof(double);
     printf("This system uses %d bytes per DOUBLE PRECISION word.\n",
 	BytesPerWord);
+    printf("The work arrays are allocated with get_huge_pages()\n");
 
     printf(HLINE);
     printf("Array size = %d, Offset = %d\n" , N, OFFSET);
' > gh_page.patch
		 patch < gh_page.patch || die "Failed to patch stream for get_huge_pages() support"
fi

# Patch for three calls to get_huge_pages
if [ "$ARRAY" = "3gh_page" ]; then
	if [ "$TLANG" != "c" ]; then
		die "Option --use-3gh_page depends on --lang-c"
	fi
	echo Patching stream for 3 calls to get_huge_pages | tee -a $RESULTS
	echo '--- stream.c	2007-03-27 13:28:59.000000000 +0100
+++ stream-gh_page.c	2008-11-04 15:15:17.000000000 +0000
@@ -45,6 +45,8 @@
 # include <float.h>
 # include <limits.h>
 # include <sys/time.h>
+# include <stdlib.h>
+# include <hugetlbfs.h>
 
 /* INSTRUCTIONS:
  *
@@ -88,9 +92,7 @@
 # define MAX(x,y) ((x)>(y)?(x):(y))
 # endif
 
-static double	a[N+OFFSET],
-		b[N+OFFSET],
-		c[N+OFFSET];
+static double	*a, *b, *c;
 
 static double	avgtime[4] = {0}, maxtime[4] = {0},
 		mintime[4] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX};
@@ -125,13 +127,22 @@
     double		scalar, t, times[4][NTIMES];
 
     /* --- SETUP --- determine precision and check timing --- */
-
+    size_t len = sizeof(double) * (N + OFFSET);
+    len = (len + gethugepagesize() - 1) & ~(gethugepagesize()-1);
+    a = get_huge_pages(len, GHP_DEFAULT);
+    b = get_huge_pages(len, GHP_DEFAULT);
+    c = get_huge_pages(len, GHP_DEFAULT);
+    if (a == NULL || b == NULL || c == NULL) {
+        printf("Failed to alloc arrays\n");
+        exit(-1);
+    }
     printf(HLINE);
     printf("STREAM version $Revision: 5.9 $\n");
     printf(HLINE);
     BytesPerWord = sizeof(double);
     printf("This system uses %d bytes per DOUBLE PRECISION word.\n",
 	BytesPerWord);
+    printf("The work arrays are allocated with get_huge_pages()\n");
 
     printf(HLINE);
     printf("Array size = %d, Offset = %d\n" , N, OFFSET);
' > gh_page.patch
		 patch < gh_page.patch || die "Failed to patch stream for get_huge_pages() support"
fi

# Patch for one call to get_hugepage_region
if [ "$ARRAY" = "gh_region" ]; then
	if [ "$TLANG" != "c" ]; then
		die "Option --use-gh_region depends on --lang-c"
	fi
	echo Patching stream for 1 call to get_hugepage_region | tee -a $RESULTS
	echo '--- stream.c	2007-03-27 13:28:59.000000000 +0100
+++ stream-gh_region.c	2008-11-04 15:15:17.000000000 +0000
@@ -45,6 +45,8 @@
 # include <float.h>
 # include <limits.h>
 # include <sys/time.h>
+# include <stdlib.h>
+# include <hugetlbfs.h>
 
 /* INSTRUCTIONS:
  *
@@ -88,9 +92,7 @@
 # define MAX(x,y) ((x)>(y)?(x):(y))
 # endif
 
-static double	a[N+OFFSET],
-		b[N+OFFSET],
-		c[N+OFFSET];
+static double	*a, *b, *c;
 
 static double	avgtime[4] = {0}, maxtime[4] = {0},
 		mintime[4] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX};
@@ -125,13 +127,20 @@
     double		scalar, t, times[4][NTIMES];
 
     /* --- SETUP --- determine precision and check timing --- */
-
+    a = get_hugepage_region(sizeof(double) * (N + OFFSET) * 3, GHR_DEFAULT);
+    b = a + N + OFFSET;
+    c = b + N + OFFSET;
+    if (a == NULL) {
+        printf("Failed to alloc arrays\n");
+        exit(-1);
+    }
     printf(HLINE);
     printf("STREAM version $Revision: 5.9 $\n");
     printf(HLINE);
     BytesPerWord = sizeof(double);
     printf("This system uses %d bytes per DOUBLE PRECISION word.\n",
 	BytesPerWord);
+    printf("The work arrays are allocated with get_huge_pages()\n");
 
     printf(HLINE);
     printf("Array size = %d, Offset = %d\n" , N, OFFSET);
' > gh_region.patch
		 patch < gh_region.patch || die "Failed to patch stream for get_hugepage_region() support"
fi

# Patch for three calls to get_hugepage_region
if [ "$ARRAY" = "3gh_region" ]; then
	if [ "$TLANG" != "c" ]; then
		die "Option --use-3gh_region depends on --lang-c"
	fi
	echo Patching stream for 3 calls to get_hugepage_region | tee -a $RESULTS
	echo '--- stream.c	2007-03-27 13:28:59.000000000 +0100
+++ stream-gh_region.c	2008-11-04 15:15:17.000000000 +0000
@@ -45,6 +45,8 @@
 # include <float.h>
 # include <limits.h>
 # include <sys/time.h>
+# include <stdlib.h>
+# include <hugetlbfs.h>
 
 /* INSTRUCTIONS:
  *
@@ -88,9 +92,7 @@
 # define MAX(x,y) ((x)>(y)?(x):(y))
 # endif
 
-static double	a[N+OFFSET],
-		b[N+OFFSET],
-		c[N+OFFSET];
+static double	*a, *b, *c;
 
 static double	avgtime[4] = {0}, maxtime[4] = {0},
 		mintime[4] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX};
@@ -125,13 +127,20 @@
     double		scalar, t, times[4][NTIMES];
 
     /* --- SETUP --- determine precision and check timing --- */
-
+    a = get_hugepage_region(sizeof(double) * (N + OFFSET), GHR_DEFAULT);
+    b = get_hugepage_region(sizeof(double) * (N + OFFSET), GHR_DEFAULT);
+    c = get_hugepage_region(sizeof(double) * (N + OFFSET), GHR_DEFAULT);
+    if (a == NULL || b == NULL || c == NULL) {
+        printf("Failed to alloc arrays\n");
+        exit(-1);
+    }
     printf(HLINE);
     printf("STREAM version $Revision: 5.9 $\n");
     printf(HLINE);
     BytesPerWord = sizeof(double);
     printf("This system uses %d bytes per DOUBLE PRECISION word.\n",
 	BytesPerWord);
+    printf("The work arrays are allocated with get_huge_pages()\n");
 
     printf(HLINE);
     printf("Array size = %d, Offset = %d\n" , N, OFFSET);
' > gh_region.patch
		 patch < gh_region.patch || die "Failed to patch stream for get_hugepage_region() support"
fi

# Patch for malloc
if [ "$ARRAY" = "malloc" ]; then
	if [ "$TLANG" != "c" ]; then
		die "Option --use-malloc-array depends on --lang-c"
	fi
	echo Patching stream for malloc | tee -a $RESULTS
	echo '--- stream.c	2009-08-13 17:19:35.000000000 +0100
+++ stream-malloc.c	2009-08-13 17:19:21.000000000 +0100
@@ -45,6 +45,7 @@
 # include <float.h>
 # include <limits.h>
 # include <sys/time.h>
+# include <stdlib.h>
 
 /* INSTRUCTIONS:
  *
@@ -94,9 +95,7 @@
 # define MAX(x,y) ((x)>(y)?(x):(y))
 # endif
 
-static double	a[N+OFFSET],
-		b[N+OFFSET],
-		c[N+OFFSET];
+static double	*a, *b, *c;
 
 static double	avgtime[4] = {0}, maxtime[4] = {0},
 		mintime[4] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX};
@@ -131,6 +130,13 @@
     double		scalar, t, times[4][NTIMES];
 
     /* --- SETUP --- determine precision and check timing --- */
+    a = (double *)malloc(sizeof(double) * (N + OFFSET) * 3);
+    b = a + N + OFFSET;
+    c = b + N + OFFSET;
+    if (a == NULL) {
+        printf("Failed to alloc arrays\n");
+        exit(-1);
+    }
 
     printf(HLINE);
     printf("STREAM version $Revision: 5.9 $\n");
@@ -138,6 +144,7 @@
     BytesPerWord = sizeof(double);
     printf("This system uses %d bytes per DOUBLE PRECISION word.\n",
 	BytesPerWord);
+    printf("The work arrays are allocated with malloc()\n");
 
     printf(HLINE);
 #ifdef NO_LONG_LONG' > malloc.patch
		 patch < malloc.patch || die "Failed to patch stream for malloc support"
fi

# Patch for stack
if [ "$ARRAY" = "stack" ]; then
	if [ "$TLANG" != "c" ]; then
		die "Option --use-stack-array depends on --lang-c"
	fi

	echo Patching stream for stack | tee -a $RESULTS
	echo '--- stream.c.orig	2008-04-01 17:11:38.000000000 +0100
+++ stream.c	2008-04-01 17:40:26.000000000 +0100
@@ -88,10 +88,6 @@
 # define MAX(x,y) ((x)>(y)?(x):(y))
 # endif
 
-static double	a[N+OFFSET],
-		b[N+OFFSET],
-		c[N+OFFSET];
-
 static double	avgtime[4] = {0}, maxtime[4] = {0},
 		mintime[4] = {FLT_MAX,FLT_MAX,FLT_MAX,FLT_MAX};
 
@@ -106,12 +102,12 @@
     };
 
 extern double mysecond();
-extern void checkSTREAMresults();
+extern void checkSTREAMresults(double *a, double *b, double *c);
 #ifdef TUNED
-extern void tuned_STREAM_Copy();
-extern void tuned_STREAM_Scale(double scalar);
-extern void tuned_STREAM_Add();
-extern void tuned_STREAM_Triad(double scalar);
+extern void tuned_STREAM_Copy(double *a, double *b, double *c);
+extern void tuned_STREAM_Scale(double scalar, double *a, double *b, double *c) ;
+extern void tuned_STREAM_Add(double *a, double *b, double *c);
+extern void tuned_STREAM_Triad(double scalar, double *a, double *b, double *c);
 #endif
 #ifdef _OPENMP
 extern int omp_get_num_threads();
@@ -123,6 +119,9 @@
     int			BytesPerWord;
     register int	j, k;
     double		scalar, t, times[4][NTIMES];
+    double	a[N+OFFSET],
+		b[N+OFFSET],
+		c[N+OFFSET];
 
     /* --- SETUP --- determine precision and check timing --- */
 
@@ -267,7 +266,7 @@
     printf(HLINE);
 
     /* --- Check Results --- */
-    checkSTREAMresults();
+    checkSTREAMresults(a, b, c);
     printf(HLINE);
 
     return 0;
@@ -322,7 +321,7 @@
         return ( (double) tp.tv_sec + (double) tp.tv_usec * 1.e-6 );
 }
 
-void checkSTREAMresults ()
+void checkSTREAMresults (double *a, double *b, double *c)
 {
 	double aj,bj,cj,scalar;
 	double asum,bsum,csum;
@@ -387,7 +386,7 @@
 	}
 }
 
-void tuned_STREAM_Copy()
+void tuned_STREAM_Copy(double *a, double *b, double *c)
 {
 	int j;
 #pragma omp parallel for
@@ -395,7 +394,7 @@
             c[j] = a[j];
 }
 
-void tuned_STREAM_Scale(double scalar)
+void tuned_STREAM_Scale(double scalar, double *a, double *b, double *c)
 {
 	int j;
 #pragma omp parallel for
@@ -403,7 +402,7 @@
 	    b[j] = scalar*c[j];
 }
 
-void tuned_STREAM_Add()
+void tuned_STREAM_Add(double *a, double *b, double *c)
 {
 	int j;
 #pragma omp parallel for
@@ -411,7 +410,7 @@
 	    c[j] = a[j]+b[j];
 }
 
-void tuned_STREAM_Triad(double scalar)
+void tuned_STREAM_Triad(double scalar, double *a, double *b, double *c)
 {
 	int j;
 #pragma omp parallel for
		 	' > stack.patch
		 patch < stack.patch || die "Failed to patch stream for stack support"
fi

# Setup libhugetlbfs for compiling
if [ "$HUGETLBFS_BDT" != "" ]; then
	if [ "$HUGETLBFS_BDT" = "BDT" ]; then
		echo Setting up libhugetlbfs for backing BSS, data and text - old relinking method | tee -a $RESULT
		LINKOPT="-Wl,--hugetlbfs-link=$HUGETLBFS_BDT"
	fi
	if [ "$HUGETLBFS_BDT" = "B" ]; then
		echo Setting up libhugetlbfs for backing BSS | tee -a $RESULT
		LINKOPT="-Wl,--hugetlbfs-link=$HUGETLBFS_BDT"
	fi
	if [ "$HUGETLBFS_BDT" = "align" ]; then
		echo Setting up libhugetlbfs for backing BSS, data and text - new relinking method | tee -a $RESULT
		LINKOPT="-Wl,--hugetlbfs-align"
	fi
	if [ ! -e $LIBHUGETLBFS_LD ] || [ ! -h $LIBHUGETLBFS_LD/ld ]; then
		die $LIBHUGETLBFS_LD does not exist or does not contain an ld symbolic link to ld.hugetlbfs
	fi

	LINKLIB=
	if [ -e /usr/lib/x86_64-linux-gnu/ ]; then
		LINKLIB=-L/usr/lib/x86_64-linux-gnu/
	fi
	for LIB in `echo $LIBHUGETLBFS_LIBPATH | tr : ' '`; do
		LINKLIB="$LINKLIB -Wl,--library-path=$LIB "
	done
	LINK_OPTIONS="$LINK_OPTIONS -B $LIBHUGETLBFS_LD $LINKOPT $LINKLIB -lhugetlbfs"
	export LD_LIBRARY_PATH=$LIBHUGETLBFS_LIBPATH

	echo Link options: $LINK_OPTIONS | tee -a $RESULT
	gcc $LINK_OPTIONS stream.c -o stream || die Failed to link against $LIBHUGETLBFS_PATH
fi

if [ "$ARRAY" = "gh_page" -o "$ARRAY" = "3gh_page" -o "$ARRAY" = "gh_region" -o "$ARRAY" = "3gh_region" ]; then

	LINKLIB=
	for LIB in `echo $LIBHUGETLBFS_LIBPATH | tr : ' '`; do
		LINKLIB="$LINKLIB -L$LIB"
	done
	LINK_OPTIONS="$LINK_OPTIONS -I$LIBHUGETLBFS_ROOT/include $LINKLIB -lhugetlbfs"
fi

# Reserve hugepages in advance if necessary
if [ "$HUGETLBFS_STACK" = "yes" -o "$HUGETLBFS_MALLOC" = "yes" -o "$HUGETLBFS_BDT" != "" -o "$ARRAY" = "gh_page" -o "$ARRAY" = "3gh_page" -o "$ARRAY" = "gh_region" -o "$ARRAY" = "3gh_region" ]; then
	gethugepagesize
	LARGEST_ARRAY=$((1<<$LARGEST_POWER))
	if [ "$HUGETLBFS_BDT" != "" ]; then
		LARGEST_ARRAY=$(($LARGEST_ARRAY+$HUGE_PAGESIZE*5))

		# Take into account oprofile pins pages
		TEST=`ps auxw | grep oprofile | grep -v grep`
		if [ "$TEST" != "" ]; then
			LARGEST_ARRAY=$(($LARGEST_ARRAY+$HUGE_PAGESIZE*20*($LARGEST_POWER-$MINIMUM_POWER)))
		fi
	fi

	if [ "$ARRAY" = "3gh_region" -o "$ARRAY" = "3gh_page" ]; then
		LARGEST_ARRAY=$(($LARGEST_ARRAY+$HUGE_PAGESIZE))
	fi

	if [ "$HUGETLBFS_STACK" = "yes" ]; then
		REQUIRED_HUGEPAGES=$(((280*1048576/$HUGE_PAGESIZE) + 36))
	else
		REQUIRED_HUGEPAGES=$((($LARGEST_ARRAY/$HUGE_PAGESIZE) + 36))
	fi
	reserve_hugepages $REQUIRED_HUGEPAGES
	adjust_wss_available_hugepages
	echo Reserved $AVAILABLE_HUGEPAGES hugepages
fi

# Run STREAM for a range of working set sizes
getdoublesize
gettempfile
STEP=0
for POWERSTEP in `seq $(($MINIMUM_POWER*$INCREMENT)) $(($LARGEST_POWER*$INCREMENT))`; do

	POWER=$(($POWERSTEP/$INCREMENT))
	START_WSS=$((1<<$POWER))
	NEXT_WSS=$((1<<($POWER+1)))
	STEP_NO=$(($POWERSTEP-($POWER*$INCREMENT)))
	STEP_SIZE=$((($NEXT_WSS-$START_WSS)/$INCREMENT*$STEP_NO))
	POWER="$POWER.$((100/$INCREMENT*$STEP_NO))"

	# Set the array size
	LARGEST_ARRAY=$(($START_WSS+$STEP_SIZE))
	ARRAY_SIZE=$(($LARGEST_ARRAY/3))
	ARRAY_SIZE=$(($ARRAY_SIZE/$DOUBLESIZE))
	OFFSET=0
	ARR_OFFSET=0

	# DEBUG
	#echo DEBUG: Power $POWER = $LARGEST_ARRAY
	#continue

	echo >> $RESULT_DIR/log.txt
	echo Running for power $POWER >> $RESULT_DIR/log.txt

	# Work out the arguements
	HUGECTL_ARGS=""
	if [ "$HUGETLBFS_STACK" = "yes" ]; then
		HUGECTL_ARGS="$HUGECTL_ARGS -s"
	fi

	if [ "$HUGETLBFS_MALLOC" = "yes" ]; then
		HUGECTL_ARGS="$HUGECTL_ARGS --heap"
	fi

	if [ "$HUGETLBFS_BDT" != "" ]; then
		HUGECTL_ARGS="$HUGECTL_ARGS --no-preload"
	fi

	if [ "$HUGETLBFS_BDT" = "align" ]; then
		HUGECTL_ARGS="$HUGECTL_ARGS --text --data"
	fi

	DEVIATE=yes
	while [ "$DEVIATE" = "yes" ]; do
		WSS=$((($ARRAY_SIZE+$ARR_OFFSET+$OFFSET)*3*$DOUBLESIZE))
		MODEL=
		if [ $WSS -gt 1800000000 ]; then
			MODEL="-mcmodel=medium"
		fi
		case "$TLANG" in 
			c)	cat stream.c | \
					#sed -e "s/#   define N\s[0-9]*/# define N $ARRAY_SIZE/" | \
					#sed -e "s/#   define OFFSET\s[0-9]*/# define OFFSET $ARR_OFFSET/" > stream.c.tmp
					#mv stream.c.tmp stream.c
					echo No patching necessary
					;;
			f)	cat stream.f | sed -e "s/PARAMETER (n=[0-9]*/PARAMETER (n=$ARRAY_SIZE/" > stream.f.tmp
					mv stream.f.tmp stream.f
					;;
			*)	die Unrecognised language $TLANG;;
		esac

		# Build the tool
		echo Building stream
		case "$TLANG" in 
			c)	echo gcc $MODEL -DN=$ARRAY_SIZE -DOFFSET=$(($ARR_OFFSET+$OFFSET)) $LINK_OPTIONS stream.c -o stream
					gcc $MODEL -DN=$ARRAY_SIZE -DOFFSET=$(($ARR_OFFSET+$OFFSET)) $LINK_OPTIONS stream.c -o stream || die Failed to compile stream
					;;
			f)	gcc -c mysecond.c || die Failed to compile mysecond.o
					g77 -c stream.f	 || die Failed to compile stream.f
					g77 $LINK_OPTIONS mysecond.o stream.o -o stream 2> /dev/null || {
				gcc -c -DUNDERSCORE mysecond.c
				g77 $MODEL mysecond.o stream.o -o stream || die "Failed to compile stream for fortran"
					}
					;;
			*)	die Unrecognised language $TLANG;;
		esac

		# Run stream $INSTANCES times
		echo -n > $TEMPFILE-rawstream
		echo -n > $RESULT_DIR/stream-raw-output-$ARRAY_SIZE.txt
		MONITOR_TAG=$LARGEST_ARRAY-$OFFSET-$ARR_OFFSET
		monitor_pre_hook $RESULT_DIR $MONITOR_TAG
		for INSTANCE in `seq 1 $INSTANCES`; do
			echo Running \"`basename $HUGECTL` $HUGECTL_ARGS stream\" no.$INSTANCE size $ARRAY_SIZE offset $OFFSET+$ARR_OFFSET wss $WSS \($LARGEST_ARRAY\)
			$HUGECTL $HUGECTL_ARGS ./stream >> $TEMPFILE-rawstream 2>&1
			if [ $? -ne 0 ]; then
				cat $TEMPFILE-rawstream
				die stream exited abnormally
			fi
		done
		monitor_post_hook $RESULT_DIR $MONITOR_TAG

		# Check if we are deviating too much
		DEVIATE=no
		for TEST in Copy Scale Add Triad; do
			grep ^$TEST: $TEMPFILE-rawstream | \
				sed -e "s/$TEST:\s*/$ARRAY_SIZE /" \
				> $TEMPFILE-$TEST
			AVG_THROUGHPUT=`awk '{print $2}' $TEMPFILE-$TEST | mean | sed -e 's/\..*//'`
			DEVIATION=`awk '{print $2}' $TEMPFILE-$TEST | stddev | sed -e 's/\..*//'`

			PERCENTAGE=0
			if [ $LARGEST_ARRAY -lt 16777216 ]; then
				PERCENTAGE=18
			elif [ $LARGEST_ARRAY -lt 134217728 ]; then
				PERCENTAGE=12
			else
				PERCENTAGE=6
			fi

			# Allow more leeway on NUMA boxen, this is less than
			# ideal because ideally STREAM would be configured
			# to run multi-threaded on each node
			if [ `awk '{print $2}' /proc/buddyinfo  | uniq | wc -l` -gt 1 ]; then
				PERCENTAGE=$((PERCENTAGE*2))
			fi

			ACCEPTABLE=$(($AVG_THROUGHPUT*$PERCENTAGE/100))
			if [ $DEVIATION -gt $ACCEPTABLE ]; then
				DEVIATE=yes
				HIGH_DEVIATION=$DEVIATION
				HIGH_ACCEPTABLE=$ACCEPTABLE
				HIGH_OP=$TEST
			fi
		done

		# Check if we deviated too much
		if [ "$DEVIATE" = "yes" -a $OFFSET -lt 16 ]; then
			echo $HIGH_OP size $ARRAY_SIZE offset $OFFSET+$ARR_OFFSET deviated too high: $HIGH_DEVIATION -gt $ACCEPTABLE >> $RESULT_DIR/log.txt
			if [ $ARR_OFFSET -gt 1024 ]; then
				ARR_OFFSET=0
				OFFSET=$(($OFFSET+1))
				ARRAY_SIZE=$(($ARRAY_SIZE-1))
			else
				ARR_OFFSET=$(($ARR_OFFSET+8))
			fi

			if [ "$NOCHECK_DEVIATION" = "yes" ]; then
				echo Deviation high but ignored for $HIGH_OP: $HIGH_DEVIATION -gt $ACCEPTABLE
				DEVIATE=no
			else
				echo Deviation too high for $HIGH_OP: $HIGH_DEVIATION -gt $ACCEPTABLE
				monitor_cleanup_hook $RESULT_DIR $MONITOR_TAG
				continue
			fi
		fi
		DEVIATE=no

		# Deviation within acceptable limits
		# Get the average throughputs and times for each test type
		for TEST in Copy Scale Add Triad; do
			grep ^$TEST: $TEMPFILE-rawstream | \
				sed -e "s/$TEST:\s*/$ARRAY_SIZE /" \
				> $TEMPFILE-$TEST
			cat $TEMPFILE-$TEST >> $RESULT_DIR/stream-$TEST.instances
			AVG_THROUGHPUT=`awk '{print $2}' $TEMPFILE-$TEST | mean`
			AVG_TIME=`awk '{print $3}' $TEMPFILE-$TEST | mean`
			DEVIATION=`awk '{print $2}' $TEMPFILE-$TEST | stddev | sed -e 's/\..*//'`
			echo "$POWER $AVG_THROUGHPUT $AVG_TIME" >> $RESULT_DIR/stream-$TEST.avg
			echo Completed $TEST at size $ARRAY_SIZE offset $OFFSET/$ARR_OFFSET deviation $DEVIATION >> $RESULT_DIR/log.txt
		done

		cat $TEMPFILE-rawstream >> $RESULT_DIR/stream-raw-output-$ARRAY_SIZE.txt
	done

	if [ $OFFSET -gt 15 ]; then
		# Only worry about results deviating at the major powers
		if [ $STEP_NO -eq 0 ]; then
			echo Deviations were too high to get a meaningful result >> $RESULT_DIR/log.txt
			die Deviations were too high to get a meaningful result
		else
			echo Deviations too high to get a result, continuing >> $RESULT_DIR/log.txt
		fi
	fi
done
grep . $RESULT_DIR/*.avg | sed -e 's/.*stream-//' | tee -a $RESULT_DIR/log.txt
rm $TEMPFILE*
reset_hugepages
echo Completed. Results: $RESULT | tee -a $RESULT
