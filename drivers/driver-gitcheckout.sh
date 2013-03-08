FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	if [ "$GITCHECKOUT_SOURCETAR" = "" ]; then
		GITCHECKOUT_SOURCETAR=none
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-gitcheckout \
		--git-tar    $GITCHECKOUT_SOURCETAR \
		--git-source $GITCHECKOUT_SOURCE \
		--first-tag  $GITCHECKOUT_FIRST \
		--second-tag $GITCHECKOUT_SECOND \
		--iterations $GITCHECKOUT_ITERATIONS \
		--cache      $GITCHECKOUT_CACHE
	return $?
}
