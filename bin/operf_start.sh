#!/bin/bash
# Script to start operf

usage() {
	echo "operf_start.sh by Vlastimil Babka"
	echo "based on oprofile_start (c) Mel Gorman 2008"
	echo "This script starts operf to monitor the process with given pid"
	echo "Operf's pid is written into operf.pid and killing operf finishes this script as well"
	echo
	echo "Usage: oprofile_start.sh [options] --pid <pid> &"
	echo "    --event               High-level oprofile event to track"
	echo "    --vmlinux             Path to vmlinux"
	echo "    --sample-cycle-factor Factor which to slow down CPU cycle sampling by"
	echo "    --sample-event-factor Factor which to slow down event sampling by"
	echo "    --callgraph N         Call graph depth"
	echo "    --systemmap           Guess"
	echo "    -h, --help            Print this help message"
	echo
	exit
}

# Parse command-line arguements
SCRIPTROOT=`echo $0 | sed -e 's/operf_start.sh$//' | sed -e 's/^\.\///'`
EVENT=default
VMLINUX=/boot/vmlinux-`uname -r`
SYSTEMMAP=/boot/System.map-`uname -r`
FACTOR=
CALLGRAPH=0
export PATH=$SCRIPTROOT:$PATH
ARGS=`getopt -o h --long help,event:,vmlinux:,systemmap:,callgraph:,sample-event-factor:,sample-cycle-factor:,pid: -n oprofile_start.sh -- "$@"`

# Cycle through arguements
eval set -- "$ARGS"
while true ; do
  case "$1" in
	--event)               EVENTS="$EVENTS $2"; shift 2;;
	--vmlinux)             VMLINUX=$2; shift 2;;
	--sample-cycle-factor) CYCLE_FACTOR="--sample-cycle-factor $2"; shift 2;;
	--sample-event-factor) EVENT_FACTOR="--sample-event-factor $2"; shift 2;;
	--callgraph)           CALLGRAPH=$2; shift 2;;
	--systemmap)           SYSTEMMAP=$2; shift 2;;
	--pid)		       ATTACHPID=$2; shift 2;;
        -h|--help) usage;;
        *) shift 1; break;;
  esac
done
if [[ -z $ATTACHPID ]]; then
    echo "No pid specified!"
    usage
    exit -1
fi

# Map the events
for EVENT in $EVENTS; do
	LOWLEVEL_EVENT="$LOWLEVEL_EVENT --event `oprofile_map_events.pl $EVENT_FACTOR $CYCLE_FACTOR --event $EVENT`"
	if [ $? -ne 0 ]; then
		echo Failed to map event $EVENT to low-level oprofile event. Verbose output follows
		oprofile_map_events.pl --event $EVENT --verbose
		exit -1
	fi
done

# Check vmlinux file exists
if [ "$VMLINUX" = "" -o ! -e $VMLINUX ]; then
	echo vmlinux file \"$VMLINUX\" does not exist
	exit -1
fi

CALLGRAPH_SWITCH=
if [ "$CALLGRAPH" != "0" ]; then
	CALLGRAPH_SWITCH="--callgraph=$CALLGRAPH"
fi

# Start operf
echo Starting up operf
echo High-level event: $EVENTS
echo Low-level event: `echo $LOWLEVEL_EVENT | sed -e 's/--event //'`
echo vmlinux: $VMLINUX
echo operf $CALLGRAPH_SWITCH $LOWLEVEL_EVENT -a --vmlinux=$VMLINUX --pid $ATTACHPID
operf $CALLGRAPH_SWITCH $LOWLEVEL_EVENT -a --vmlinux=$VMLINUX --pid $ATTACHPID &
OPERFPID=$!
echo $OPERFPID >> operf.pid

# wait until operf finishes and indicate that it finished
wait $OPERFPID
rm -f operf.pid

exit 0
