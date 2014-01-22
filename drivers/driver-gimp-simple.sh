FINEGRAINED_SUPPORTED=no
NAMEEXTRA=

run_bench() {
	$SHELLPACK_INCLUDE/shellpack-bench-gimp-simple -i $GIMP_SIMPLE_IMAGE_LOCATION
	return $?
}
