#!/bin/bash

bash opcontrol --dump

fixup_oprofile() {
	TIFS=$IFS
	LIFS="
"
	IFS=$LIFS
	echo WARNING: Having to patch up oprofile output
	echo ===========================================
	opreport
	echo ===========================================
	
	for LINE in `opreport 2>&1 > /dev/null`; do
		IFS=$TIFS
		echo "$LINE" | grep "opreport error"
		if [ $? -eq 0 ]; then
			FULLNAME=`echo $LINE | awk -F 'filename: '  '{print $2}'`
			FILENAME=`basename "$FULLNAME"`.`date +%s`
			echo Moving "$FULLNAME" to "$HOME/$FILENAME"
			mv "$FULLNAME" "$HOME/$FILENAME"
		fi

		echo "$LINE" | grep "opreport error: basic_string::"
		if [ $? -eq 0 ]; then
			for DIR in `find /var/lib/oprofile/samples/ | grep "{anon:/"`; do
				echo Removing samples $DIR
				rm -rf $DIR
			done
		fi
		IFS=$LIFS
	done
		
	IFS="$LIFS"
}

# Try and fix up opreport if it has shit samples
opreport > /dev/null
while [ $? -ne 0 ]; do
	sleep 1
	fixup_oprofile
	opreport > /dev/null
done

MODULES="-p /lib/modules/`uname -r`/kernel"
if [ "$1" = "" ]; then
	echo ======= short report =========
	opreport $MODULES || exit -1

	echo ======= long report =========
	opreport $MODULES -l || exit -1
else
	echo ======= short report =========  > $1
	opreport $MODULES >> $1 || exit -1

	echo ======= long report ========= >> $1
	opreport $MODULES -l >> $1 || exit -1
fi

if [ "$OPROFILE_REPORT_ANNOTATE" != "no" ]; then
	if [ "`which recode`" != "" ]; then
		# Decode with
		# grep -A 9999999 "=== annotate ===" oprofile-compressed.report | grep -v annotate | recode /b64..char | gunzip -c | less
		if [ "$1" = "" ]; then
			echo ====== annotate ========
			opannotate --assembly $MODULES | gzip -c | recode ../b64
		else
			echo ====== annotate ======== >> $1
			opannotate --assembly $MODULES | gzip -c | recode ../b64 >> $1
		fi
	else
		if [ "$1" = "" ]; then
			echo ====== annotate ========
			opannotate --assembly $MODULES
		else
			echo ====== annotate ======== >> $1
			opannotate --assembly $MODULES >> $1
		fi
	fi
fi

exit 0
