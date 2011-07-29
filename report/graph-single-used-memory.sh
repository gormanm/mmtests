#!/bin/bash
# Plot free memory over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config

. $SCRIPTDIR/common-cmdline-parser.sh
START=`head -1 tests-timestamp-$KERNEL | awk '{print $3}'`
. $SCRIPTDIR/common-testname-markup.sh

zcat proc-vmstat-$KERNEL-*.gz | perl -e "\$timestamp = 0;
while (<>) {
	if (/^time: ([0-9]*)/) {
		\$timestamp=(\$1-$START);
	}
	if (/^nr_free_pages ([.0-9]*)/) {
		\$used=($PRESENT_PAGES-\$1)*4096;
		print \"\$timestamp \$used\n\";
	}
}" > used-pages.plot-unsorted
sort -n used-pages.plot-unsorted > used-pages.plot
rm used-pages.plot-unsorted

$PLOT --mem-usage \
	--title "$NAME $KERNEL Memory Usage" \
	--format "postscript color" \
	--titles memory-used \
	--extra $TMPDIR/$NAME-extra \
	--yrange 0:$PRESENT_MB \
	--dump \
	--output $OUTPUTDIR/memory-usage-$NAME.ps \
	used-pages.plot > $OUTPUTDIR/memory-usage-$NAME.gp
echo Generated memory-usage-$NAME.ps
