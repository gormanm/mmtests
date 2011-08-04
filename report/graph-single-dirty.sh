#!/bin/bash
# Plot dirty memory over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh
. $SCRIPTDIR/common-testname-markup.sh

zcat proc-vmstat-$KERNEL-*.gz | perl -e "\$timestamp = 0;
while (<>) {
	if (/^time: ([0-9]*)/) {
		\$timestamp=(\$1-$START);
	}
	if (/^nr_dirty ([.0-9]*)/) {
		\$dirty=\$1*4096;
		print \"\$timestamp \$dirty\n\";
	}
}" > dirty-pages.plot-unsorted
sort -n dirty-pages.plot-unsorted > dirty-pages.plot
rm dirty-pages.plot-unsorted

$PLOT --mem-usage \
	--title "$NAME $KERNEL Dirty Pages" \
	--format "postscript color" \
	--titles dirty-memory \
	--yrange 0:$(($PRESENT_KB/1024)) \
	--dump \
	--output $OUTPUTDIR/dirty-$NAME.ps \
	dirty-pages.plot > $OUTPUTDIR/dirty-$NAME.gp
echo Generated dirty-$NAME.ps
