#!/bin/bash

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`
source $SCRIPTDIR/lib/sh/funcs.sh

VMREGRESS_DIR=$SCRIPTDIR/../
HOSTNAME=`hostname`
RELEASE=`uname -r`
AIM9_DIR=/usr/src/aim9
RESULT_DIR=/root/vmregressbench-`uname -r`/aim9
TESTTIME=60
FINISH=disk_rr
EXTRA=


# Print usage of command
usage() {
  echo "bench-aim9.sh (c) Mel Gorman 2005"
  echo This script runs an aim9 test and records some statistics around about
  echo the time of the test.
  echo
  echo "Usage: bench-aim9.sh [options]"
  echo "    -a, --aim      AIM9 install directory (default: $AIM9_DIR)"
  echo "    -v, --vmr      VMRegress install directory (default: $VMREGRESS_DIR)"
  echo "    -r, --result   Result directory (default: $RESULT_DIR)"
  echo "    -t, --time     Duration to run each test(default: $TESTTIME)"
  echo "    -e, --extra    String to append to result dir"
  echo "    -f, --finish   Test to finish on (default: $FINISH)"
  echo "    -o, --oprofile Collect oprofile information"
  echo "    -h, --help     Print this help message"
  echo
  exit
}

# Parse command line arguements
ARGS=`getopt -o ha:v:r:t:e:f:o --long help,aim:,vmr:,result:,time:,extra:,finish:,oprofile -n bench-aim9.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
  	-a|--aim)    export AIM9_DIR="$2"; shift 2;;
	-v|--vmr)    export VMREGRESS_DIR="$2"; shift 2;;
	-r|--result) export RESULT_DIR="$2"; shift 2;;
	-t|--time)   export TESTTIME="$2"; shift 2;;
	-e|--extra)  export EXTRA="$2"; shift 2;;
	-f|--finish) export FINISH="$2"; shift 2;;
	-o|--oprofile) export OPROFILE=1; shift 1;;
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done

if [ "$EXTRA" != "" ]; then
  export EXTRA=-$EXTRA
fi
export RESULT_DIR=$RESULT_DIR$EXTRA

# Setup results directory
START=`date +%s`
RESULTS=$RESULT_DIR/log.txt
if [ -e $RESULT_DIR ]; then
  echo Results directory \($RESULT_DIR\) already exists
  echo Run with --help for options
  exit
fi

if [ ! -e "$VMREGRESS_DIR" ]; then
  echo VMRegress does not exist
  echo Run with --help for options
  exit
fi

if [ ! -e "$AIM9_DIR" ]; then
  echo AIM9 is not installed at $AIM9_DIR does not exist
  echo Run with --help for options
  exit
fi

# Determines if expect will be used or not
EXPECT=`which expect`

START=`date +%s`
mkdir -p "$RESULT_DIR"
if [ ! -e "$RESULT_DIR" ]; then
  echo Failed to create results directory
  echo Run with --help for options
  exit
fi

echo AIM9 Test $EXTRA > $RESULTS
echo Start date: `date`
echo Start date: `date` >> $RESULTS
uname -a >> $RESULTS
if [ ! -e $RESULTS ]; then
  echo Unable to create results file
  exit
fi

echo Recording basic statistics
echo Buddyinfo at start of test >> $RESULTS
echo -------------------------- >> $RESULTS
cat /proc/buddyinfo >> $RESULTS
echo >> $RESULTS

if [ "$OPROFILE" != "" ]; then
  echo Purging /var/lib/oprofile
  rm -rf /var/lib/oprofile/*

  echo Starting oprofile
  opcontrol --setup --vmlinux=/boot/vmlinux-`uname -r`
  opcontrol --start
fi

# Prepare for test
cd $AIM9_DIR
if [ ! -e /tmp/aim9 ]; then
  mkdir /tmp/aim9
fi

if [ "$EXPECT" != "" ]; then
  echo Creating expect script
  echo "#!/bin/bash
# \\
export PATH=.:$PATH
# \\
exec expect -f vmregress_expect

spawn ./singleuser
expect \"s name\"             { exp_send $HOSTNAME\r }
expect \"s configuration\"    { exp_send $RELEASE\r  }
expect \"Number of seconds\"  { exp_send $TESTTIME\r }
expect \"Path to disk files\" { exp_send /tmp/aim9\r }
while {1} {
  expect $FINISH exit
}
" > vmregress_expect
  chmod u+x vmregress_expect

  echo Running aim9 expect script
  ./vmregress_expect | tee -a $RESULTS
else
  TEMP=`mktemp`
  echo $HOSTNAME > $TEMP
  echo $RELEASE  >> $TEMP
  echo $TESTTIME >> $TEMP
  echo /tmp/aim9 >> $TEMP
  ./singleuser < $TEMP | tee -a $RESULTS
  rm $TEMP
fi

echo Recording basic statistics
echo Buddyinfo at end of test >> $RESULTS
echo -------------------------- >> $RESULTS
cat /proc/buddyinfo >> $RESULTS
echo >> $RESULTS

if [ "$OPROFILE" != "" ]; then
  echo Dumping oprofile information
  opcontrol --stop
  echo OProfile Result >> $RESULTS
  echo --------------- >> $RESULTS
  opreport -l --show-address >> $RESULTS
fi

echo >> $RESULTS
echo >> $RESULTS
END=`date +%s`
echo Test Completed >> $RESULTS
echo -------------- >> $RESULTS
echo End date: `date` >> $RESULTS
echo Duration: $(($END-$START)) >> $RESULTS
echo Completed. Results: $RESULTS
