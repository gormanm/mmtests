#!/bin/bash
# Plot free pages over order-3 over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-testname-markup.sh

echo > freeorder3.plot-unsorted
for FILE in `ls proc-buddyinfo-$KERNEL-*.gz`; do
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
}" >> freeorder3.plot-unsorted
done
sort -n freeorder3.plot-unsorted | grep -v '^$' > freeorder3.plot
rm freeorder3.plot-unsorted

$PLOT \
	--title "$NAME $KERNEL Unusable Free Space Index" \
	--format "postscript color" \
	--titles freeorder-3 \
	--extra $TMPDIR/$NAME-extra \
	--dump \
	--output $OUTPUTDIR/freeorder3-$NAME.ps \
	freeorder3.plot > $OUTPUTDIR/freeorder3-$NAME.gp
echo Generated freeorder3-$NAME.ps
