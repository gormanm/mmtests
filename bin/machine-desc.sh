#!/bin/bash
# machine-desc.sh - Describe the machine in some sort of fashion

export SCRIPT=`basename $0 | sed -e 's/\./\\\./'`
export SCRIPTDIR=`echo $0 | sed -e "s/$SCRIPT//"`/..
. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SHELLPACK_INCLUDE/include-sizes.sh
export PATH=$SCRIPTDIR/bin:$PATH
ARCH=`uname -m`
get_numa_details

install-depends dmidecode

##
# cpuinfo_val - Output the given value of a cpuinfo field
cpuinfo_val() {
	grep "^$1" /proc/cpuinfo | awk -F": " '{print $2}' | head -1
}

detect_dmidecode() {
	# Common to all arches
	# Lookup primary cache information
	cache=/sys/devices/system/cpu/cpu0/cache
	pcache=
	for index in `ls /sys/devices/system/cpu/cpu0/cache`; do
		if [ "$pcache" != "" ]; then
			pcache="$pcache + "
		fi
		pcache="$pcache`cat $cache/$index/size`"
		pcache="$pcache `cat $cache/$index/type | head -c1`"
	done
	hw_memory=`free -m | grep ^Mem: | awk '{print $2}'`MB
	hw_cpus=`grep processor /proc/cpuinfo | wc -l`
	hw_sockets=`grep "physical id" /proc/cpuinfo | sort | uniq | wc -l`

	case "$ARCH" in
		i?86|x86_64|ia64)

			if [ "`which dmidecode`" = "" ]; then
				warning dmidecode is not in path, very limited info
			fi

			hw_manu=`dmidecode -s baseboard-manufacturer`
			hw_prod=`dmidecode -s baseboard-product-name`
			hw_vers=`dmidecode -s baseboard-version`

			hw_model="$hw_manu $hw_prod $hw_vers"
			hw_cpu_name=`cpuinfo_val "model name"`
			hw_cpu_mhz=`cpuinfo_val "cpu MHz"`
			hw_ncoresperchip=`cpuinfo_val "cpu cores"`
			hw_nchips=$(($hw_cpus/$hw_ncoresperchip))
			hw_ncores=$(($hw_cpus/$hw_nchips))
			hw_pcache=$pcache

			;;
		ppc64)
			hw_cpu_name=`cpuinfo_val cpu`
			hw_cpu_mhz=`cpuinfo_val "clock"`
			hw_pcache=$pcache
			;;
	esac
}

detect_dmidecode

cat <<EOF
`hostname`

Basic Details
-------------
hw_model         : $hw_model
hw_prod          : $hw_prod
hw_vers          : $hw_vers
hw_cpu_name      : $hw_cpu_name
hw_cpu_mhz       : $hw_cpu_mhz
hw_nr_cpus:      : $hw_cpus
hw_cpu_sockets   : $hw_sockets
hw_cpu_cores     : $hw_nchips
hw_core_threads  : $hw_ncores
hw_pcache        : $hw_pcache
hw_memory        : $hw_memory
hw_memory_nodes  : $NUMNODES

Memory Topology
---------------
`numactl --hardware`

CPU Topology
------------
`list-cpu-toplogy.sh`
EOF

echo
printf "%-16s %4s %5s %8s %5s %3s\n" hostname cpus sockt mem nodes cpu
printf "%-16s %4d %5d %8s %5d %s\n" `hostname` $hw_cpus $hw_sockets ${hw_memory} $NUMNODES "$hw_cpu_name"
