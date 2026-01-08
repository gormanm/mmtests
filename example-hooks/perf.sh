# Run perf-record for each subtest.  To use it, source this file or copy
#  the functions to your config file and add the export below:
#  MONITOR_HOOKS="perf-install perf-record"

perf-install_monitor-init() {
	zypper install -y perf
}

perf-record_monitor-pre () {
	local logdir=$1
	local subtest=$2

	perf record -a -o $logdir/profile-$subtest-cycles.data &
	echo $! > $logdir/perf.pid
}
perf-record_monitor-post() {
	local logdir=$1
	local subtest=$2

	# terminate perf
	kill $(cat $logdir/perf.pid)
	rm $logdir/perf.pid
}

perf-record_monitor-end() {
	for name in $(find work/log/$RUNNAME -name "profile-*") ; do
		pushd $(dirname $name)
		prof=$(basename $name)

		echo Creating perf archive of $prof
		perf archive $prof
		perf report --stdio -s sample,period,comm,dso,sym \
		     -i $prof > $prof.txt
		perf report --stdio -s sample,period,comm,dso,sym,cpu \
		     -i $prof > $prof-cpu.txt
		perf report --header --stdio -s sample,period,comm,dso \
		     -i $prof > $prof-dso.txt
		gzip $prof ${prof}.txt ${prof}-cpu.txt ${prof}-dso.txt
		popd
	done
}
