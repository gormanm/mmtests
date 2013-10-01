FINEGRAINED_SUPPORTED=yes
NAMEEXTRA=

run_bench() {
	BIND_SWITCH=
	if [ "$KU_LATENCY_BINDING" != "" ]; then
		BIND_SWITCH=--bind-$KU_LATENCY_BINDING
	fi
	$SHELLPACK_INCLUDE/shellpack-bench-ku_latency $BIND_SWITCH	\
		--run-seconds "${KU_LATENCY_RUN_SECONDS}"		\
		--start-send-first "${KU_LATENCY_START_SEND_FIRST}"
	return $?
}
