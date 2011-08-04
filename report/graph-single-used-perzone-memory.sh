#!/bin/bash
# Plot free memory over time

DIRNAME=`dirname $0`
SCRIPTDIR=`cd "$DIRNAME" && pwd`
PLOT=$SCRIPTDIR/plot
. $SCRIPTDIR/../config
. $SCRIPTDIR/common-cmdline-parser.sh
. $SCRIPTDIR/common-testname-markup.sh

zcat proc-zoneinfo-$KERNEL-*.gz | perl -e "\$timestamp = 0;
while (<>) {
	if (/^time: ([0-9]*)/) {
		\$timestamp=(\$1-$START);
	}
	if (/^Node ([0-9]*), zone\s*([A-Za-z_0-9]*)/) {
		\$nodezone=\"node-\$1-zone-\$2\";
		\$present=0;
		\$used=0;
	}

	if (/present\s*([0-9]*)/) {
		\$present=\$1;
	}

	if (/nr_free_pages\s*([.0-9]*)/) {
		\$used=(\$present-\$1)*4096;
		if (\$used < 0) { \$used = 0; }
		print \"\$timestamp \$nodezone \$used\n\";
	}
}" > perzone-used-pages.plot-unsorted
sort -n perzone-used-pages.plot-unsorted > perzone-used-pages.plot
rm perzone-used-pages.plot-unsorted

PLOTS=
TITLES=
for ZONE in `awk '{print $2}' perzone-used-pages.plot | sort | uniq`; do
	grep "$ZONE " perzone-used-pages.plot | awk '{print $1" "$3}' > perzone-used-pages.plot-$ZONE
	if [ "$PLOTS" != "" ]; then
		PLOTS="$PLOTS "
		TITLES="$TITLES,"
	fi
	PLOTS="${PLOTS}perzone-used-pages.plot-$ZONE"
	TITLES="${TITLES}$ZONE"
done

$PLOT --mem-usage \
	--title "$NAME $KERNEL Per Zone Memory Usage" \
	--format "postscript color" \
	--titles $TITLES \
	--extra $TMPDIR/$NAME-extra \
	--yrange 0:$PRESENT_MB \
	--dump \
	--output $OUTPUTDIR/perzone-memory-usage-$KERNEL-$NAME.ps \
	$PLOTS > $OUTPUTDIR/perzone-memory-usage-$KERNEL-$NAME.gp
echo Generated perzone-memory-usage-$KERNEL-$NAME.ps
