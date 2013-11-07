export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
source $SCRIPTDIR/lib/sh/funcs.sh

VMREGRESS_DIR=/usr/src/vmregress
KERNEL_TAR=/usr/src/linux-2.6.29.tar.gz
BUILD_DIR=/usr/src/bench-stresshighalloc-test
RESULT_DIR=/root/vmregressbench-`uname -r`/highalloc-heavy
EXTRA=

getpagesize		# Sets PAGESIZE
gethugepagesize		# Sets HUGE_PAGESIZE
gethugetlb_order	# Sets HUGETLB_ORDER
getmemtotals		# Sets MEMTOTAL_BYTES and MEMTOTAL_PAGES
HIGHALLOC_ORDER=$HUGETLB_ORDER
HIGHALLOC_COUNT=0
HIGHALLOC_GFPFLAGS="GFP_HIGHUSER_MOVABLE"
SEQ=6

# Print usage of command
usage() {
  echo "bench-stresshighalloc.sh (c) Mel Gorman 2005"
  echo This script takes a kernel source tree and performs the following
  echo test on it
  echo 1. Untar to $BUILD_DIR
  echo 2. Copy and start building the tree as each copy finishes. $SEQ copies are made and
  echo "    build with -j1"
  echo 3. Start building the main copy
  echo 4. After 1 minute, try allocate and pin $HIALLOC_COUNT 2\*\*10 pages
  echo 5. Immediately after, try again to see has reclaim made a difference
  echo 6. Wait 30 seconds
  echo 7. Kill all compiles and delete the source trees
  echo 8. Try and allocate 2\*\*10 pages again
  echo
  echo "Usage: bench-stresshighalloc.sh [options]"
  echo "    -t, --tar      Kernel source tree to use (default: $KERNEL_TAR)"
  echo "    -b, --build    Directory to build in (default: $BUILD_DIR)"
  echo "    -k, --kernels  Number of trees to compile (default: $SEQ)"
  echo "    -r, --result   Result directory (default: $RESULT_DIR)"
  echo "    -e, --extra    String to append to result dir"
  echo "    -v, --vmr      VMRegress install directory (default: $VMREGRESS_DIR)"
  echo "    -o, --oprofile Collect oprofile information"
  echo "    -s, --order    Size of the pages to allocate (default: $HIGHALLOC_ORDER)"
  echo "    -c, --count    Number of pages to allocate (default: $HIGHALLOC_COUNT)"
  echo "    -z, --highmem  User high memory if possible (default: no)"
  echo "    -f, --freemem  Min free kb as a percentage of total memory"
  echo "    --percent N    Only try and allocation N% of memory"
  echo "    --ms-delay     Milliseconds to delay between allocations (default: 100)"
  echo "    --mb-per-sec   Delay allocations to that the given MB-per-second is scheduled for IO"
  echo "    --gfp-flags    GFP allocation flags to use in allocation (default: $HIGHALLOC_GFPFLAGS)"
  echo "    -h, --help     Print this help message"
  echo
  exit 1
}

# Parse command line arguements
ARGS=`getopt -o hf:k:t:b:r:e:s:c:ozv: --long help,freemem:,kernels:,tar:,build:,result:,extra:,order:,count:,oprofile,highmem,vmr:,ms-delay:,mb-per-sec:,percent:,gfp-flags: -n bench-stresshighalloc.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
	-t|--tar)    export KERNEL_TAR="$2"; shift 2;;
	-f|--freemem) export MINFREE_PERCENTAGE="$2"; shift 2;;
	-b|--build)  export BUILD_DIR="$2"; shift 2;;
	-k|--kernels)export SEQ="$2"; shift 2;;
	-r|--result) export RESULT_DIR="$2"; shift 2;;
	-e|--extra)  export EXTRA="$2"; shift 2;;
	-v|--vmr)    export VMREGRESS_DIR="$2"; shift 2;;
	-o|--oprofile) export OPROFILE=1; shift 1;;
	-z|--highmem) export HIGHMEM="gfp_highuser=1"; shift 1;;
	-s|--order)  export HIGHALLOC_ORDER="$2"; shift 2;;
	-c|--count)  export HIGHALLOC_COUNT="$2"; shift 2;;
	--ms-delay)  export MS_DELAY="$2"; shift 2;;
	--mb-per-sec) export MB_PER_SEC="$2"; shift 2;;
	--gfp-flags) export HIGHALLOC_GFPFLAGS="$2"; shift 2;;
	--percent)    export HIGHALLOC_PERCENT="$2"; shift 2;;
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done

if [ "$EXTRA" != "" ]; then
  export EXTRA=-$EXTRA
fi
export RESULT_DIR=$RESULT_DIR$EXTRA

if [ "$HIGHALLOC_COUNT" = "0" ]; then
	echo -n "Discovering number of pages to allocate: "
	HIGHALLOC_COUNT=$(($MEMTOTAL_BYTES/$HUGE_PAGESIZE))
	if [ "$HIGHALLOC_PERCENT" != "" ]; then
  		HIGHALLOC_COUNT=$(($HIGHALLOC_COUNT*$HIGHALLOC_PERCENT/100))
	fi
	echo $HIGHALLOC_COUNT
fi

if [ "$MS_DELAY" != "" ]; then
	MS_DELAY_INT=`printf "%d" "$MS_DELAY"`
	if [ "$MS_DELAY" != "$MS_DELAY_INT" ]; then
		echo Millisecond delay must be specified as an integer
		exit -1
	fi
	if [ $MS_DELAY -le 0 ]; then
		MS_DELAY=1
	fi
	MS_DELAY="$MS_DELAY"
fi

if [ "$MB_PER_SEC" != "" ]; then
	MB_PER_SEC_INT=`printf "%d" "$MB_PER_SEC"`
	if [ "$MB_PER_SEC" != "$MB_PER_SEC" ]; then
		echo Megabytes per second must be specified as an integer
		exit -1
	fi
	if [ $MB_PER_SEC -le 0 ]; then
		MB_PER_SEC=1
	fi

	# Adjust the MS delay accordingly
	BYTES_PER_MS=$(($MB_PER_SEC*1048576/1000))
	ALLOC_PAGESIZE=$(($PAGESIZE*(1<<$HIGHALLOC_ORDER)))
	MS_DELAY=$(($ALLOC_PAGESIZE/$BYTES_PER_MS))
	echo Adjusted ms_delay to $MS_DELAY for $MB_PER_SEC megabytes per second IO queues
fi

if [ "$MINFREE_PERCENTAGE" != "" ]; then
  MINFREE_BYTES=$(($MEMTOTAL_BYTES*$MINFREE_PERCENTAGE/100))
  MINFREE_KBYTES=$(($MINFREE_BYTES/1024))
  echo Setting minfree to $MINFREE_KBYTES
  echo $MINFREE_KBYTES > /proc/sys/vm/min_free_kbytes
fi

if [ -f /proc/sys/vm/hugepages_treat_as_movable ]; then
	echo Treating hugepages as Movable
	echo 1 > /proc/sys/vm/hugepages_treat_as_movable
fi

echo "Pagesize:         $PAGESIZE"
echo "Huge Pagesize:    $HUGE_PAGESIZE"
echo "HugeTLB Order:    $HUGETLB_ORDER"
echo "High alloc count: $HIGHALLOC_COUNT"

cat $SHELLPACK_STAP/highalloc.stp | sed \
	-e "s/define PARAM_MSDELAY.*/define PARAM_MSDELAY $MS_DELAY/" \
	-e "s/define PARAM_ALLOCS.*/define PARAM_ALLOCS $HIGHALLOC_COUNT/" \
	-e "s/define PARAM_GFPFLAGS.*/define PARAM_GFPFLAGS $HIGHALLOC_GFPFLAGS/" \
	-e "s/define PARAM_ORDER.*/define PARAM_ORDER $HUGETLB_ORDER/" > /tmp/highalloc.stp

# Setup results directory
RESULTS=$RESULT_DIR/log.txt
if [ -e $RESULT_DIR ]; then
  echo Results directory \($RESULT_DIR\) already exists
  echo Run with --help for options
  exit 1
fi

if [ ! -e "$BUILD_DIR" ]; then
  echo Build directory \($BUILD_DIR\) does not exist
  echo Run with --help for options
  exit 1
fi

if [ ! -e "$KERNEL_TAR" ]; then
  echo Kernel tar does not exist
  echo Run with --help for options
  exit 1
fi

if [ ! -e "$VMREGRESS_DIR" ]; then
  echo VMRegress does not exist
  echo Run with --help for options
  exit 1
fi

START=`date +%s`
mkdir -p "$RESULT_DIR"
if [ ! -e "$RESULT_DIR" ]; then
  echo Failed to create results directory
  echo Run with --help for options
  exit 1
fi

if [ "$OPROFILE" != "" ]; then
  echo Purging /var/lib/oprofile
  rm -rf /var/lib/oprofile/*

  echo Starting oprofile
  opcontrol --setup --vmlinux=/boot/vmlinux-`uname -r`
  opcontrol --start
fi

echo HighAlloc Reasonable Stress Test $EXTRA > $RESULTS
echo Start date: `date`
echo Start date: `date` >> $RESULTS
uname -a >> $RESULTS
if [ ! -e $RESULTS ]; then
  echo Unable to create results file
  exit 1
fi

# Get the tar zip flag
echo Using Kernel tar: $KERNEL_TAR
case $KERNEL_TAR in
*.tgz|*.gz)
        export ZIPFLAG=z
        ;;
*.bz2)
        export ZIPFLAG=j
        ;;
*)
        echo Do not recognised kernel tar type $KERNEL_TAR
        exit 1
        ;;
esac

echo VMRegress building in $BUILD_DIR
df -h

cd $BUILD_DIR
echo Deleting old trees from last run
TREE=`tar -t${ZIPFLAG}f "$KERNEL_TAR" | grep ^linux- | head -1 | sed -e 's/\///'`
if [ "$TREE" = "" ]; then
  echo ERROR: Could not determine build tree name from tar file
  exit 1
fi
echo Deleting: "$TREE*"
rm $TREE* -rf

echo Expanding tree
tar -${ZIPFLAG}xf "$KERNEL_TAR"
cd $BUILD_DIR/$TREE
make clean

for i in `seq 1 $SEQ`; do
  echo Copying and making copy-$i
  cd ..
  rm -rf $TREE-copy-$i
  cp -r $TREE $TREE-copy-$i
  if [ ! -d $TREE-copy-$i ]; then
    echo ERROR: Failed to make copy $TREE-copy-$i. Probably out of disk space
    exit 1
  fi
  cd $TREE-copy-$i
  make clean > /dev/null 2> /dev/null
  make defconfig > /dev/null 2> /dev/null
  make -j1 > /dev/null 2> ../error-$i.txt &
done

echo Making primary
cd ../$TREE
make defconfig > /dev/null 2> /dev/null
make -j1 > /dev/null 2> ../error-primary.txt &
cd ..

echo Sleeping 5 minutes

for i in `seq 1 10`; do
  sleep 30

  # Check for errors
  for i in `seq 1 $SEQ` primary; do
    TEST=`grep Error error-$i.txt | grep ^make`
    if [ "$TEST" != "" ]; then
      echo ERROR: An error was reported by compile job $i
      TEST=`grep "Input/output error" error-$i.txt`
      if [ "$TEST" = "" ]; then
        cat error-$i.txt
        exit 1
      fi
      echo "       Failed to IO error (crappy smbfs possibly), restarting"
      if [ "$i" = "primary" ]; then
        cd $TREE || exit
      else
        cd $TREE-copy-$i || exit
      fi
      make -j1 > /dev/null 2> ../error-$i.txt &
      cd ..
    fi
  done
done

echo Trying high alloc
echo Buddyinfo at start of highalloc test >> $RESULTS
echo ------------------------------------ >> $RESULTS
cat /proc/buddyinfo >> $RESULTS
echo >> $RESULTS

STARTALLOC=`date +%s`
stap -g /tmp/highalloc.stp | tee /tmp/highalloc.out
ENDALLOC=`date +%s`
sleep 5

echo >> $RESULTS
echo HighAlloc Under Load Test Results Pass 1 >> $RESULTS
echo ---------------------------------------- >> $RESULTS
cat /tmp/highalloc.out >> $RESULTS
grep -A 15 "Test completed" /tmp/highalloc.out
echo Duration alloctest pass 1: $(($ENDALLOC-$STARTALLOC)) >> $RESULTS

STARTALLOC=`date +%s`
stap -g /tmp/highalloc.stp | tee /tmp/highalloc.out
ENDALLOC=`date +%s`
sleep 5

echo >> $RESULTS
echo HighAlloc Under Load Test Results Pass 2 >> $RESULTS
echo ---------------------------------------- >> $RESULTS
cat /tmp/highalloc.out >> $RESULTS
grep -A 15 "Test completed" /tmp/highalloc.out
echo Duration alloctest pass 2: $(($ENDALLOC-$STARTALLOC)) >> $RESULTS

echo >> $RESULTS
echo Buddyinfo at end of highalloc test >> $RESULTS
echo --------------------------------- >> $RESULTS
cat /proc/buddyinfo >> $RESULTS
echo >> $RESULTS

echo Waiting in `pwd` for 180 seconds
sleep 180

echo Killing compile process
killall -KILL make
killall -KILL cc1

#### Before delete
cd $RESULT_DIR/mapfrag-before-delete
echo Recording stats
cat /proc/buddyinfo > buddyinfo

#### After delete
cd $RESULT_DIR/mapfrag-after-delete
echo Deleting trees and recording more stats
rm $BUILD_DIR/$TREE* -rf
cat /proc/buddyinfo > buddyinfo

cat /proc/buddyinfo > buddyinfo
cat /proc/pagetypeinfo > pagetypeinfo 2> /dev/null

#### At End
echo DDing large file and deleting to flush buffer caches
size=`free -m | grep Mem: | awk '{print $2}'`
dd if=/dev/zero of=$BUILD_DIR/largefile ibs=1048576 count=$size
cat $BUILD_DIR/largefile > /dev/null
rm $BUILD_DIR/largefile

if [ -e /proc/sys/vm/drop_caches ]; then
  echo Attempting to drop all caches
  echo 3 > /proc/sys/vm/drop_caches
fi

OLDMINFREE=`cat /proc/sys/vm/min_free_kbytes`
echo 1024 > /proc/sys/vm/min_free_kbytes

echo Rerunning highalloc test at rest
echo >> $RESULTS
echo HighAlloc Test Results while Rested >> $RESULTS
echo ----------------------------------- >> $RESULTS
STARTALLOC=`date +%s`
stap -g /tmp/highalloc.stp | tee /tmp/highalloc.out
ENDALLOC=`date +%s`

cat /tmp/highalloc.out >> $RESULTS
grep -A 15 "Test completed" /tmp/highalloc.out

# Reset min free kbytes
echo $OLDMINFREE > /proc/sys/vm/min_free_kbytes
