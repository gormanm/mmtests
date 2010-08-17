STARTING_HUGEPAGES=`cat /proc/sys/vm/nr_hugepages`
AVAILABLE_HUGEPAGES=`cat /proc/sys/vm/nr_hugepages`
MOUNTED_HUGETLBFS=no
HUGETLBFS_MNT=$HOME/hugetlbfs

reserve_hugepages() {
	REQUIRED_HUGEPAGES=$1
	ATTEMPT=0

	# Ensure hugepages are supported
	if [ ! -e /proc/sys/vm/nr_hugepages ]; then
		echo ERROR: hugepages do not appear to be supported
		exit 1
	fi

	# Mount hugetlbfs if necessary
	TEST=`mount | grep "type hugetlbfs"`
	if [ "$TEST" = "" ]; then
		mkdir $HUGETLBFS_MNT
		mount -t hugetlbfs none $HUGETLBFS_MNT || exit 1
		export MOUNTED_HUGETLBFS=yes
	fi

	# Reserve the number of hugepages required for the test
	gethugepagesize
	echo $REQUIRED_HUGEPAGES > /proc/sys/vm/nr_hugepages || die Failed to write to /proc/sys/vm/nr_hugepages
	while [ `cat /proc/sys/vm/nr_hugepages` -ne $REQUIRED_HUGEPAGES -a $ATTEMPT -lt 40 ]; do
		ATTEMPT=$(($ATTEMPT+1))
		echo Hugepage reserve attempt $ATTEMPT: `cat /proc/sys/vm/nr_hugepages`
		sleep 2
		echo 0 > /proc/sys/vm/drop_caches
		echo 1 > /proc/sys/vm/drop_caches
		echo 2 > /proc/sys/vm/drop_caches
		echo $REQUIRED_HUGEPAGES > /proc/sys/vm/nr_hugepages
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

