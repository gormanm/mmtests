FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	EXTRA=
	if [ "$LARGECOPY_SRCTAR_EXTRA" != "" ]; then
		EXTRA="--srctar $LARGECOPY_SRCTAR_EXTRA"
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-largecopy \
		--srctar $LARGECOPY_SRCTAR $EXTRA \
		--targetsize $LARGECOPY_TARGETSIZE_MB
}
