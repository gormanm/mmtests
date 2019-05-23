NAMEEXTRA=

run_bench() {
	$SCRIPTDIR/shellpacks/shellpack-bench-pagealloc \
		--min-order $PAGEALLOC_ORDER_MIN \
		--max-order $PAGEALLOC_ORDER_MAX \
		--gfp-flags $PAGEALLOC_GFPFLAGS
	return $?
}
