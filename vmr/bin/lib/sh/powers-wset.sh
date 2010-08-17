getwordsize
if [ $WORDSIZE -eq 4 ]; then
	LARGEST_POWER=30
else
	LARGEST_POWER=32
fi
LARGEST_ARRAY=$[1<<$LARGEST_POWER]
MAX_POWERS="-m $LARGEST_POWER"
SAMPLES="-s 2"
COMPILE_BITSIZE=
MINIMUM_POWER=15

check_compile_64bitsize() {
	if [ $LARGEST_POWER -gt 31 ]; then
		echo Compiling for 64 bit
		COMPILE_BITSIZE="-m64"
	fi
}

adjust_wss_available_hugepages() {
	# If enough hugepages could not be reserved, drop the maximum
	# array size and do that instead
	if [ $AVAILABLE_HUGEPAGES -ne $REQUIRED_HUGEPAGES ]; then
		echo WARNING: Failed to reserve $REQUIRED_HUGEPAGES hugepages required
		echo Successfully got $AVAILABLE_HUGEPAGES hugepages
		while [ $REQUIRED_HUGEPAGES -gt $AVAILABLE_HUGEPAGES  -a $LARGEST_POWER -gt $MINIMUM_POWER ]; do
			LARGEST_POWER=$[$LARGEST_POWER-1]
			LARGEST_ARRAY=$[1<<$LARGEST_POWER]
			REQUIRED_HUGEPAGES=$((($LARGEST_ARRAY/$HUGE_PAGESIZE) + 1))
		done

		if [ $LARGEST_POWER -le $MINIMUM_POWER ]; then
			echo Failed to reserve minimum number of hugepages required
			echo Hugepage size: $HUGE_PAGESIZE
			echo Buddyinfo was
			cat /proc/buddyinfo
			reset_hugepages
			die Failed to reserve minimum number of hugepages required
		fi
		echo Using max powers value of $LARGEST_POWER instead
		export MAX_POWERS="-m $LARGEST_POWER";
	fi

}

parse_max_powers() {
	LARGEST_POWER=$1
	if [ $LARGEST_POWER -gt 30 -a $WORDSIZE -eq 4 ]; then
		echo WARNING: 32-bit arch cannot exceed a size of 30 for malloc. Using 30
		LARGEST_POWER=30
	fi
	export MAX_POWERS="-m $LARGEST_POWER";
	LARGEST_ARRAY=$[1<<$LARGEST_POWER]
}
