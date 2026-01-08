# call_user_hooks can be invoked both by the main mmtests script and by
# the benchmark driver script, as long as the hooks are exported.  See
# export_user_hooks.
call_user_hooks() {
	local typ=$1
	shift 1
	for hook in $MONITOR_HOOKS ; do
		if [[ $(type -t ${hook}_monitor-${typ}) == function ]] ; then
			echo "Invoking user hook ${hook}_monitor-${typ}"
			eval ${hook}_monitor-${typ} $@ || die Failed to execute user hook ${hook}_monitor-${typ}
			echo "user hook ${hook}_monitor-${typ} terminated with status $?"
		fi
	done
}

# Expose user defined hooks to test driver.
export_user_hooks() {
	for h in $MONITOR_HOOKS ; do
		for t in init pre post end; do
			if [[ $(type -t ${h}_monitor-$t) == function ]] ; then
				echo export -f ${h}_monitor-${t}
				export -f ${h}_monitor-${t} 2>/dev/null
			fi
		done
	done
}
