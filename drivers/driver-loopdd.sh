FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	EXTRA=
	if [ "$LARGECOPY_SRCTAR_EXTRA" != "" ]; then
		EXTRA="--srctar $LARGECOPY_SRCTAR_EXTRA"
	fi
	SYNC_PARAM=
	if [ "$LARGECOPY_SYNC" = "yes" ]; then
		SYNC_PARAM=--sync
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-loopdd \
		--srctar $LARGECOPY_SRCTAR $EXTRA $SYNC_PARAM \
		--targetsize $LARGECOPY_TARGETSIZE_MB \
		--iterations $LARGECOPY_ITERATIONS
	return $?
}
