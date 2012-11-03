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
	export cache=/sys/devices/system/cpu/cpu0/cache
	export pcache=
	for index in `ls /sys/devices/system/cpu/cpu0/cache`; do
		if [ "$pcache" != "" ]; then
			pcache="$pcache + "
		fi
		export pcache="$pcache`cat $cache/$index/size`"
		export pcache="$pcache `cat $cache/$index/type | head -c1`"
	done
	export hw_memory=`free -m | grep ^Mem: | awk '{print $2}'`MB
	export hw_cpus=`grep processor /proc/cpuinfo | wc -l`

	ARCH=`uname -m`
	case "$ARCH" in
		i?86|x86_64|ia64)

			if [ "`which dmidecode`" = "" ]; then
				warning dmidecode is not in path, very limited info
			fi

			export hw_manu=`dmidecode -s baseboard-manufacturer`
			export hw_prod=`dmidecode -s baseboard-product-name`
			export hw_vers=`dmidecode -s baseboard-version`

			export hw_model="$hw_manu $hw_prod $hw_vers"
			export hw_cpu_name=`cpuinfo_val "model name"`
			export hw_cpu_mhz=`cpuinfo_val "cpu MHz"`
			export hw_ncoresperchip=`cpuinfo_val "cpu cores"`
			export hw_siblings=`cpuinfo_val siblings`
			export hw_nchips=$(($hw_cpus/$hw_ncoresperchip))
			export hw_ncores=$(($hw_cpus/$hw_nchips))
			export hw_pcache=$pcache

			export hw_ht_enabled=Yes
			if [ $hw_siblings -eq $hw_ncoresperchip ]; then
				export hw_ht_enabled=No
			fi

			;;
		ppc64)
			export hw_cpu_name=`cpuinfo_val cpu`
			export hw_cpu_mhz=`cpuinfo_val "clock"`
			export hw_pcache=$pcache
			;;
	esac
}
