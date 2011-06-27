#!/bin/bash
# Plot transparent hugepage usage over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh

for SINGLE_KERNEL in $KERNEL; do
	FIRST_KERNEL=$SINGLE_KERNEL
	break
done

COPY=$KERNEL
KERNEL=$FIRST_KERNEL
START=`head -1 tests-timestamp-$FIRST_KERNEL | awk '{print $3}'`
. $SCRIPTDIR/common-testname-markup.sh
KERNEL=$COPY

PLOTS=
TITLES=
for SINGLE_KERNEL in $KERNEL; do
	PLOTS="$PLOTS proc-vmstat-$SINGLE_KERNEL.plot"
	START=`head -1 tests-timestamp-$SINGLE_KERNEL | awk '{print $3}'`
	zcat proc-vmstat-$SINGLE_KERNEL-*.gz | perl -e "\$timestamp = 0;
	while (<>) {
		if (/^time: ([0-9]*)/) {
			\$timestamp=(\$1-$START);
		}
		if (/^nr_anon_transparent_hugepages ([.0-9]*)/) {
			\$thp=\$1;
			print \"\$timestamp \$thp\n\";
		}
	}" > proc-vmstat-$SINGLE_KERNEL.plot-unsorted
	sort -n proc-vmstat-$SINGLE_KERNEL.plot-unsorted > proc-vmstat-$SINGLE_KERNEL.plot
	rm proc-vmstat-$SINGLE_KERNEL.plot-unsorted

	if [ "$TITLES" != "" ]; then
		TITLES=$TITLES,
	fi
	TITLES="$TITLES$SINGLE_KERNEL"
done

$PLOT --thp-count \
	--title "$NAME Transparent Huge Pages Count Comparison" \
	--format "postscript color" \
	--titles $TITLES \
	--extra /tmp/$NAME-extra \
	--dump \
	--output $OUTPUTDIR/thp-comparison-$NAME.ps \
	$PLOTS > $OUTPUTDIR/thp-comparison-$NAME.gp
echo Generated thp-comparison-$NAME.ps
