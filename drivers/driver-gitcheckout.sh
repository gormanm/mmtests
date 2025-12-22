
run_bench() {
	if [ "$GITCHECKOUT_SOURCETAR" = "" ]; then
		GITCHECKOUT_SOURCETAR=none
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-gitcheckout \
		--commits    $GITCHECKOUT_COMMITS \
		--iterations $GITCHECKOUT_ITERATIONS \
		--cache      $GITCHECKOUT_CACHE
	return $?
}
