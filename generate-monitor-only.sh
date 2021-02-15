#!/bin/bash
DIRNAME=`dirname $0`
export SCRIPTDIR=`cd "$DIRNAME" && pwd`
CONFIG=$SCRIPTDIR/config
INCLUDE_PERF=
INCLUDE_FTRACE=

usage() {
	echo "$0 [-mn] [-c path_to_config] runname"
	echo
	echo "-c|--config             Use MMTests config, suggest configs/config-monitor"
	echo "-p|--enable-perf-hook   Enable perf profiling"
	echo "-t|--enable-ftrace-hook Enable Ftrace tracing"
	echo "-h|--help               Prints this help."
}

# Parse command-line arguments
ARGS=`getopt -o hpc:t --long help,enable-perf-hook,config:,enable-ftrace-hook -n generate-monitor-only.sh -- "$@"`
eval set -- "$ARGS"
while true; do
	case "$1" in
		-c|--config)
			CONFIG=$2
			shift 2
			;;
		-h|--help)
			usage
			KVM_ARGS="$KVM_ARGS $1"
			exit $SHELLPACK_SUCCESS
			;;
		-p|--enable-perf-hook)
			INCLUDE_PERF=yes
			shift
			;;
		-t|--enable-ftrace-hook)
			INCLUDE_FTRACE=yes
			shift
			;;
		--)
			break
			;;
		*)
			echo ERROR: Unrecognised option $1
			usage
			exit $SHELLPACK_ERROR
			;;
	esac
done

git diff --quiet
if [ $? -ne 0 ]; then
	echo ERROR: Tree is dirty, changes will not be included in self-extracting script
	exit -1
fi

# Take the unparsed option as the parameter
shift
export RUNNAME=$1

if [ -z "$RUNNAME" ]; then
	echo "ERROR: Runname parameter must be specified"
	usage
	exit -1
fi

. $SCRIPTDIR/shellpacks/common.sh
. $SCRIPTDIR/shellpacks/common-config.sh
. $SCRIPTDIR/shellpacks/monitors.sh

# Generate reference tree
echo Creating reference tree
mkdir -p $SHELLPACK_TEMP || die Failed to create temporary directory
cd $SHELLPACK_TOPLEVEL
if [ ! -e run-mmtests.sh -a ! -e .git ]; then
	die Failed to identify top-level mmtests git tree
	exit -1
fi
gitref=$(git log --pretty=reference -1)
git archive --format=tar --prefix=mmtests-monitor-$RUNNAME/ `git rev-parse HEAD` | gzip -c - > $SHELLPACK_TEMP/mmtests-monitor-${RUNNAME}.tar.gz || die Failed to create $SHELLPACK_TEMP/mmtests-monitor-${RUNNAME}.tar.gz
cd $SHELLPACK_TEMP || die Failed to switch to temporary directory
tar -xf mmtests-monitor-${RUNNAME}.tar.gz || die Failed to expand reference tree
cd $SHELLPACK_TEMP/mmtests-monitor-${RUNNAME} || die Failed to switch to reference tree
TREE_MMTESTS=$SHELLPACK_TEMP/mmtests-monitor-${RUNNAME}

echo Copying configuration
echo 'DIRNAME=`dirname $0`' > $TREE_MMTESTS/config || die Failed to write $TREE_MMTESTS/config
echo 'SCRIPTDIR=`cd "$DIRNAME" && pwd`' >> $TREE_MMTESTS/config
echo 'export PATH=$SCRIPTDIR/bin:$PATH' >> $TREE_MMTESTS/config
echo 'export SWAP_CONFIGURATION=default' >> $TREE_MMTESTS/config
echo 'export MMTESTS=monitor' >> $TREE_MMTESTS/config
grep "export RUN_" $CONFIG >> $TREE_MMTESTS/config || die Failed to copy profile parameters
grep "export OPROFILE_REPORT" $CONFIG >> $TREE_MMTESTS/config
echo 'export RUN_MONITOR=yes' >> $TREE_MMTESTS/config
grep "export MONITOR" $CONFIG >> $TREE_MMTESTS/config
sed -i -e '/^#/d' $TREE_MMTESTS/config

echo Altering auto-install commands
sed -i -e 's/install -y/install/' $TREE_MMTESTS/bin/install-depends
sed -i -e '/install-depends/d' $TREE_MMTESTS/run-mmtests.sh
sed -i -e '/cpupower e2fsprogs/d' $TREE_MMTESTS/run-mmtests.sh
sed -i -e '/make numactl/d' $TREE_MMTESTS/run-mmtests.sh
sed -i -e '/wget xfsprogs/d' $TREE_MMTESTS/run-mmtests.sh

echo Altering top-level execution script
sed -i -e '/reset_transhuge/d' $TREE_MMTESTS/run-mmtests.sh
sed -i -e '/Using default TESTDISK_DIR/d' $TREE_MMTESTS/run-mmtests.sh

if [ "$INCLUDE_PERF" = "yes" ]; then
	echo Adding perf hook
	mv $TREE_MMTESTS/profile-disabled-hooks-perf.sh $TREE_MMTESTS/profile-hooks-perf.sh
fi
if [ "$INCLUDE_FTRACE" = "yes" ]; then
	echo Adding ftrace hook
	mv $TREE_MMTESTS/profile-disabled-hooks-trace-cmd.sh $TREE_MMTESTS/profile-hooks-trace-cmd.sh
fi


echo Removing some scripts
rm $TREE_MMTESTS/generate-monitor-only.sh
rm $TREE_MMTESTS/profile-disabled-hooks*
rm $TREE_MMTESTS/README
rm $TREE_MMTESTS/CHANGELOG
rm $TREE_MMTESTS/run-kvm.sh
rm -rf $TREE_MMTESTS/configs
rm -rf $TREE_MMTESTS/micro
rm -rf $TREE_MMTESTS/shellpack_src/addon
rm -rf $TREE_MMTESTS/shellpack_src/packs
mkdir $TREE_MMTESTS/shellpack_src/src-tmp
mv $TREE_MMTESTS/shellpack_src/src/monitor $TREE_MMTESTS/shellpack_src/src-tmp
mv $TREE_MMTESTS/shellpack_src/src/refresh.sh $TREE_MMTESTS/shellpack_src/src-tmp
rm -rf $TREE_MMTESTS/shellpack_src/src
mv $TREE_MMTESTS/shellpack_src/src-tmp $TREE_MMTESTS/shellpack_src/src
rm -rf $TREE_MMTESTS/stap-patches
rm -rf $TREE_MMTESTS/stap-scripts
rm -rf $TREE_MMTESTS/subreport
rm -rf $TREE_MMTESTS/vmr
rm -rf $TREE_MMTESTS/bin-virt
mkdir $TREE_MMTESTS/bin-tmp
for BIN in install-depends unbuffer run-single-test.sh mmtests-rev-id list-cpus-allowed list-cpu-siblings.pl list-cpu-toplogy.sh; do
	mv $TREE_MMTESTS/bin/$BIN $TREE_MMTESTS/bin-tmp
done
rm -rf $TREE_MMTESTS/bin
mv $TREE_MMTESTS/bin-tmp $TREE_MMTESTS/bin
mkdir $TREE_MMTESTS/drivers/tmp
mv $TREE_MMTESTS/drivers/driver-monitor.sh $TREE_MMTESTS/drivers/tmp
rm $TREE_MMTESTS/drivers/driver-*.sh
mv $TREE_MMTESTS/drivers/tmp/driver-monitor.sh $TREE_MMTESTS/drivers
rmdir $TREE_MMTESTS/drivers/tmp

TMP_SCRIPTDIR=$SCRIPTDIR
. $TREE_MMTESTS/config
SCRIPTDIR=$TMP_SCRIPTDIR
mkdir $TREE_MMTESTS/monitors/tmp
for MONITOR in $MONITORS_GZIP $MONITORS_WITH_LATENCY; do
	mv $TREE_MMTESTS/monitors/watch-$MONITOR.* $TREE_MMTESTS/monitors/tmp
done
rm $TREE_MMTESTS/monitors/watch-*.sh
rm $TREE_MMTESTS/monitors/watch-*.pl
mv $TREE_MMTESTS/monitors/tmp/* $TREE_MMTESTS/monitors/
rmdir $TREE_MMTESTS/monitors/tmp

echo Creating tarball of mmtests in monitor-only mode
pushd $SHELLPACK_TEMP
tar -czf mmtests-monitor-${RUNNAME}.tar.gz mmtests-monitor-${RUNNAME} || die Failed to create tarball

echo Creating self-executing script
cat > $SCRIPTDIR/gather-monitor-${RUNNAME}.sh << EOF
#!/bin/bash
# Head git-commit `git rev-parse HEAD`

HEADER=\`awk '/^=== BEGIN MONITOR SCRIPTS ===/ { print NR + 1; exit 0; }' \$0\`
tail -n +\$HEADER \$0 | base64 -d > mmtests-monitor-${RUNNAME}.tar.gz
if [ \$? -ne 0 ]; then
	echo ERROR: Failed to self-extract, aborting.
	exit -1
fi
tar -xzf mmtests-monitor-${RUNNAME}.tar.gz
if [ \$? -ne 0 ]; then
	echo ERROR: Failed to extract embedded tar archive
	exit -1
fi
rm mmtests-monitor-${RUNNAME}.tar.gz

if [ "\$1" = "--extract" ]; then
	echo Extracted to \`pwd\`/mmtests-monitor-$RUNNAME
	exit 0
fi

cd mmtests-monitor-$RUNNAME
if [ \$? -ne 0 ]; then
	echo ERROR: Failed to access monitor scripts
	exit -1
fi

RET=0
if [ "\$1" = "--verify" ]; then
	MONITORS=\`grep "export MONITORS_" config | awk -F = '{print \$2}' | sed -e 's/"//g'\`
	echo Checking monitor binary dependencies
	for BINDEP_SPEC in perl:perl-base expect:expect tclsh:tcl gzip:gzip; do
		BINDEP=\`echo \$BINDEP_SPEC | awk -F : '{print \$1}'\`
		PACKAGE=\`echo \$BINDEP_SPEC | awk -F : '{print \$2}'\`
		if [ "\`which \$BINDEP 2>/dev/null\`" = "" ]; then
			echo Basic binary depencency \$BINDEP not in path, install \$PACKAGE
			RET=-1
		else
			echo Baseline \$BINDEP OK
		fi
	done

	for MONITOR in \$MONITORS; do
		BINDEPS=\`grep BinDepend: monitors/watch-\$MONITOR.* | awk -F Depend: '{print \$2}'\`
		for BINDEP_SPEC in \$BINDEPS; do
			BINDEP=\`echo \$BINDEP_SPEC | awk -F : '{print \$1}'\`
			PACKAGE=\`echo \$BINDEP_SPEC | awk -F : '{print \$2}'\`
			if [ "\`which \$BINDEP 2>/dev/null\`" = "" ]; then
				echo Monitor \$MONITOR binary depencency \$BINDEP not in path, install \$PACKAGE
				RET=-1
			else
				echo Monitor \$MONITOR OK
			fi
		done
	done

	if [ \$RET -ne 0 ]; then
		echo WARNING: Monitors missing binary dependencies, some logs will not be captured
	fi
	cd ..
else
	echo Executing monitor script, follow instructions on screen
	./run-mmtests.sh $RUNNAME
	cp config $SHELLPACK_LOG_BASE_SUBDIR/
	echo "${gitref}" > $SHELLPACK_LOG_BASE_SUBDIR/gitref
	PACKAGENAME="logs-$RUNNAME-\`hostname\`-\`date +%Y%m%d-%H%M-%S\`.tar.gz"
	tar -czf ../\$PACKAGENAME $SHELLPACK_LOG_BASE_SUBDIR
	RET=\$?

	if [ \$RET -ne 0 ]; then
		cd ..
		rm -rf mmtests-monitor-$RUNNAME
		echo ERROR: Failed to archive logs gathered
	else
		cd ..
		echo Logs successfully packed in \$PACKAGENAME
		LATESTNAME="logs-$RUNNAME-\`hostname\`-LATEST.tar.gz"
		rm -f \$LATESTNAME
		ln -s \$PACKAGENAME \$LATESTNAME
		echo Created soft link \$LATESTNAME
	fi
fi

rm -rf mmtests-monitor-$RUNNAME

exit \$RET
=== BEGIN MONITOR SCRIPTS ===
EOF
base64 mmtests-monitor-${RUNNAME}.tar.gz >> $SCRIPTDIR/gather-monitor-${RUNNAME}.sh || \
	die Failed to base64 encode tar file
cp mmtests-monitor-${RUNNAME}.tar.gz /tmp/
popd > /dev/null
rm -rf $SHELLPACK_TEMP
chmod u+x $SCRIPTDIR/gather-monitor-${RUNNAME}.sh

echo Success
echo Self-extracting script located at $SCRIPTDIR/gather-monitor-${RUNNAME}.sh

exit $SHELLPACK_SUCCESS
