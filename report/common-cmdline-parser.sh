# Basic report script command parser
NAME=hostname_example
KERNEL=
WORKINGDIR=

while [ "$1" != "" ]; do
	case "$1" in
		-k|--kernel)
			KERNEL=$2
			shift 2
			;;
		-n|--name)
			NAME=$2
			shift 2
			;;
		-t|--titles)
			FORCE_TITLES=$2
			shift 2
			;;
		-w|--working-dir)
			WORKINGDIR=$2
			cd $WORKINGDIR || exit -1
			WORKINGDIR=`pwd`
			cd - > /dev/null
			shift 2
			;;
		-a|--arch)
			ARCH=$2
			shift 2
			;;
	esac
done

if [ "$WORKINGDIR" = "" ]; then
	WORKINGDIR=$NAME
fi

OUTPUTDIR=`pwd`
cd $WORKINGDIR || exit -1
WORKINGDIR=`pwd`

if [ "$KERNEL" = "" ]; then
	echo Specify some kernel names to look at
	exit -1
fi

FILTERED_KERNEL=
for SINGLE_KERNEL in $KERNEL; do
	if [ ! -e tests-timestamp-$SINGLE_KERNEL ]; then
		echo WARN: $WORKINGDIR/test-timestamp-$SINGLE_KERNEL does not exist
	else
		if [ "$FILTERED_KERNEL" = "" ]; then
			FILTERED_KERNEL=$SINGLE_KERNEL
		else
			FILTERED_KERNEL="$FILTERED_KERNEL $SINGLE_KERNEL"
		fi
	fi
done
PRESENT_KB=`grep MemTotal: tests-timestamp-$SINGLE_KERNEL | head -1 | awk '{print $2}'`
PRESENT_MB=$((PRESENT_KB/1024))
PRESENT_PAGES=$(($PRESENT_KB/4))
KERNEL="$FILTERED_KERNEL"
