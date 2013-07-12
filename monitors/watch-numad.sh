#!/bin/bash
install-depends numad

# We're managing numad now
/etc/init.d/numad stop || exit -1
NUMAD_BIN=/usr/sbin/numad
if [ ! -e $NUMAD_BIN ]; then
	NUMAD_BIN=/usr/bin/numad
fi
if [ ! -e $NUMAD_BIN ]; then
	exit -1
fi

TAILPID=

shutdown_numad() {
	$NUMAD_BIN -i 0
	kill $TAILPID
	exit 0
}
	
trap shutdown_numad SIGTERM

$NUMAD_BIN -i 5 || exit -1
tail -1f /var/log/numad.log &
TAILPID=$!
wait $TAILPID
