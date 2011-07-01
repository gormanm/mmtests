export SHELLPACK_ERROR=-1
export SHELLPACK_SUCCESS=0

if [ "`which check-confidence.pl`" = "" ]; then
	export PATH=$SCRIPTDIR/stat:$PATH
fi

function die() {
	rm -rf $SHELLPACK_TEMP
	echo "FATAL: $@"
	exit $SHELLPACK_ERROR
}

function check_status() {
	EXITCODE=$?

	if [ $EXITCODE != 0 ]; then
		echo "ERROR: $@"
		rm -rf $SHELLPACK_TEMP
		exit $SHELLPACK_ERROR
	fi

	echo $1 fine
}

function save_rc() {
	"$@"
	echo $? > "/tmp/shellpack-rc.$$"
}

function recover_rc() {
	EXIT_CODE=`cat /tmp/shellpack-rc.$$`
	rm -f /tmp/shellpack-rc.$$
	( exit $EXIT_CODE )
}

function sources_fetch() {
	WEB=$1
	MIRROR=$2
	OUTPUT=$3

	echo "$P: Fetching from mirror $MIRROR"
	wget -q -O $OUTPUT $MIRROR
	if [ $? -ne 0 ]; then
		if [ "$WEB" = "NOT_AVAILABLE" ]; then
			die Benchmark is not publicly available. You must make it available from a local mirror
		fi
			
		echo "$P: Fetching from internet $WEB"
		wget -q -O $OUTPUT $WEB
		if [ $? -ne 0 ]; then
			die "$P: Could not download $WEB"
		fi
	fi
}

function git_fetch() {
	GIT=$1
	TREE=$2
	MIRROR=$3
	OUTPUT=$4

	echo "$P: Fetching from mirror $MIRROR"
	wget -q -O $OUTPUT $MIRROR
	if [ $? -ne 0 ]; then
		if [ "$GIT" = "NOT_AVAILABLE" ]; then
			die Benchmark is not publicly available. You must make it available from a local mirror
		fi
			
		echo "$P: Cloning from internet $GIT"
		git clone $GIT $TREE
		if [ $? -ne 0 ]; then
			die "$P: Could not clone $GIT"
		fi
		cd $TREE || die "$P: Could not cd $TREE"
		echo Creating $OUTPUT
		git archive --format=tar --prefix=$TREE/ master | gzip -c > $OUTPUT
	fi
}

export TRANSHUGE_AVAILABLE=no
if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
	export TRANSHUGE_AVAILABLE=yes
fi

function enable_transhuge() {
	if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo always > /sys/kernel/mm/transparent_hugepage/enabled
	fi
}

function disable_transhuge() {
	if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo never > /sys/kernel/mm/transparent_hugepage/enabled
	fi
}

function reset_transhuge() {
	if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
		echo $VM_TRANSPARENT_HUGEPAGES_DEFAULT > /sys/kernel/mm/transparent_hugepage/enabled
	else
		if [ "$VM_TRANSPARENT_HUGEPAGES_DEFAULT" != "never" ]; then
			echo Tests configured to use THP but it is unavailable
			exit
		fi
	fi
}
