#!/bin/bash
# Plot IO reads and writes over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh
. $SCRIPTDIR/common-testname-markup.sh

cat iostat-$KERNEL-* | perl -e "
\$timestamp = 0;
my \$reads =  0;
my \$writes = 0;
my \$count = -2;
while (<>) {
	\$line = \$_;
	if (\$line =~ /Device:/) {
		if (\$count >= 0) {
			print \"\$timestamp \$reads \$writes\n\";
		}
		\$count++;
		\$reads = 0;
		\$writes = 0;
		(\$dummy, \$timestamp, \$dummy) = split(/\s/, \$line);
		\$timestamp -= $START;
		next;
	}
	if (\$count < 0) {
		next;
	}
	if (\$line =~ / [0-9.]*\s[0-9.]*\s[0-9.]* -- ([a-zA-Z-0-9]*)\s+[0-9.]*\s+[0-9.]*\s+[0-9.]*\s+([0-9]*)\s+([0-9]*)/) {
		\$reads += \$2;
		\$writes += \$3;
	}
}" > iostat.plot-unsorted
sort -n iostat.plot-unsorted > iostat.plot
rm iostat.plot-unsorted

$PLOT --iostat-blocks \
	--title "$NAME $KERNEL IO reads/writes" \
	--format "postscript color" \
	--extra $TMPDIR/$NAME-extra \
	--dump \
	--output $OUTPUTDIR/iostat-$NAME.ps \
	iostat.plot > $OUTPUTDIR/iostat-$NAME.gp
echo Generated iostat-$NAME.ps
