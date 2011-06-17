#!/bin/bash
# Plot the worst latency for IRQs being disabled

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
	PLOTS="$PLOTS irqsoff-$SINGLE_KERNEL.plot"
	START=`head -1 tests-timestamp-$SINGLE_KERNEL | awk '{print $3}'`
	zcat irqsoff-$SINGLE_KERNEL-*.gz | perl -e "\$timestamp = 0;
	while (<>) {
		if (/^time: ([0-9]*)/) {
			\$timestamp=(\$1-$START);
		}
		if (/^\\# latency: ([0-9]*) ([a-z]*).*/) {
			\$latency=\$1;
			if (\$2 ne \"us\") {
				print \"UNEXPECTED TIMEUNIT\n\";
			}
			print \"\$timestamp \$latency\n\";
		}
	}" > irqsoff-$SINGLE_KERNEL.plot-unsorted
	sort -n irqsoff-$SINGLE_KERNEL.plot-unsorted > irqsoff-$SINGLE_KERNEL.plot
	rm irqsoff-$SINGLE_KERNEL.plot-unsorted

	if [ "$TITLES" != "" ]; then
		TITLES=$TITLES,
	fi
	TITLES="$TITLES$SINGLE_KERNEL"
done

$PLOT --irqsoff \
	--title "$NAME Worst IRQs Disabled Latency" \
	--format "postscript color" \
	--titles $TITLES \
	--logscaleY \
	--dump \
	--output $OUTPUTDIR/irqsoff-worstlatency-$NAME.ps \
	$PLOTS > $OUTPUTDIR/irqsoff-worstlatency-$NAME.gp
echo Generated irqsoff-worstlatency-$NAME.ps
