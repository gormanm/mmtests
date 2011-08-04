#!/bin/bash
# Plot unusuable free index over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh
. $SCRIPTDIR/common-testname-markup.sh

echo > unusable-index.plot-unsorted
for FILE in `ls buddyinfo-$KERNEL-*.gz`; do
	zcat $FILE | perl -e "\$timestamp = 0;
while (<>) {
	if (/^Record: ([0-9]*).*/) {
		\$timestamp=(\$1-$START)/60;
	}
	if (/^extfrag_lruhuge\s+ unusable_freespace_index: ([.0-9]*).*/) {
		print \"\$timestamp \$1\n\";
	}
}" >> unusable-index.plot-unsorted
done
sort -n unusable-index.plot-unsorted > unusable-index.plot
rm unusable-index.plot-unsorted

$PLOT --unusable-index \
	--title "$NAME $KERNEL Unusable Free Space Index" \
	--format "postscript color" \
	--titles unusable-index \
	--extra $TMPDIR/$NAME-extra \
	--yrange 0:1 \
	--dump \
	--output $OUTPUTDIR/unusable-index-$NAME.ps \
	unusable-index.plot > $OUTPUTDIR/unusable-index-$NAME.gp
echo Generated unusable-index-$NAME.ps
