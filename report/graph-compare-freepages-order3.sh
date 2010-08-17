#!/bin/bash
# Plot free pages over order-3 over time

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
	PLOTS="$PLOTS freeorder3-$SINGLE_KERNEL.plot"
	START=`head -1 tests-timestamp-$SINGLE_KERNEL | awk '{print $3}'`

	echo > freeorder3-$SINGLE_KERNEL.plot-unsorted
	for FILE in `ls proc-buddyinfo-$SINGLE_KERNEL-*.gz`; do
		zcat $FILE | perl -e "\$timestamp = 0;
\$freepages = 0;
while (<>) {
	if (/^time: ([0-9]*).*/) {
		if (\$timestamp > 0) {
			print \"\$timestamp \$freepages\n\";
			\$freepages = 0;
		}
		\$timestamp=(\$1-$START)/60;
	}
	if (/^Node /) {
		@counts = split(/\\s+/);
		for (\$order = 3; \$counts[4+\$order] ne \"\"; \$order++) {
			\$count = \$counts[4+\$order];
			\$freepages += (\$count << (\$order-3));
		}
		
	}
	}" >> freeorder3-$SINGLE_KERNEL.plot-unsorted
	done
	sort -n freeorder3-$SINGLE_KERNEL.plot-unsorted | grep -v '^$' > freeorder3-$SINGLE_KERNEL.plot
	rm freeorder3-$SINGLE_KERNEL.plot-unsorted
	if [ "$TITLES" != "" ]; then
		TITLES=$TITLES,
	fi
	TITLES="$TITLES$SINGLE_KERNEL"
done

$PLOT \
	--title "$NAME Unusable Free Space Index" \
	--format "postscript color" \
	--titles $TITLES \
	--extra /tmp/$NAME-extra \
	--dump \
	--output $OUTPUTDIR/freeorder3-$NAME.ps \
	$PLOTS > $OUTPUTDIR/freeorder3-$NAME.gp
echo Generated freeorder3-$NAME.ps
