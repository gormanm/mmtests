##
# cpuinfo_val - Output the given value of a cpuinfo field
cpuinfo_val() {
	grep "^$1" /proc/cpuinfo | awk -F": " '{print $2}' | head -1
}

##
# detect_mconf - Detect machine configuration
# emit_mconf - Emit machine HW configuration
# emit_onlymconf - Emit mconf and exit
detect_mconf() {
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
			hw_siblings=`cpuinfo_val siblings`
			hw_nchips=$(($hw_cpus/$hw_ncoresperchip))
			hw_ncores=$(($hw_cpus/$hw_nchips))
			hw_pcache=$pcache

			hw_ht_enabled=Yes
			if [ $hw_siblings -eq $hw_nw_ncoresperchip ]; then
				hw_ht_enabled=No
			fi

			;;
		ppc64)
			hw_cpu_name=`cpuinfo_val cpu`
			hw_cpu_mhz=`cpuinfo_val "clock"`
			hw_pcache=$pcache
			;;
	esac
}
