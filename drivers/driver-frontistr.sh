$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh revocapbuild
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh blasbuild
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh metisbuild
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh scalapackbuild
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh mumpsbuild
$SHELLPACK_TOPLEVEL/shellpack_src/src/refresh.sh trilinosbuild

run_bench() {
	VERSION_PARAM=
	if [ "$FRONTISTR_VERSION" != "" ]; then
		VERSION_PARAM="-v $FRONTISTR_VERSION"
	fi
	BIND_SWITCH=
	if [ "$FRONTISTR_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$FRONTISTR_BINDING
	fi

	$SHELLPACK_INCLUDE/shellpack-bench-frontistr $VERSION_PARAM $BIND_SWITCH \
		--mpi-processes $FRONTISTR_MPI_PROCESSES	\
		--omp-threads   $FRONTISTR_OMP_THREADS		\
		--model         $FRONTISTR_MODEL		\
		--iterations    $FRONTISTR_ITERATIONS
	return $?
}
