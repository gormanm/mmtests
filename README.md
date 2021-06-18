# Overview

MMTests is a configurable test suite that runs performance tests
against arbitrary workloads. This is not the only test framework
but care is taken to make sure the test configurations are accurate,
representative and reproducible. Reporting and analysis is common across
all benchmarks. Support exists for gathering additional telemetry while
tests are running and hooks exist for more detailed tracing using
[ftrace](https://www.kernel.org/doc/html/latest/trace/ftrace.html)
or [perf](https://perf.wiki.kernel.org/).

# Quick Introduction

The top-level directory has a single driver script called `run-mmtests.sh`
which reads a config file that describes how the benchmarks should be
configured and executed. In some cases, the same benchmarking tool may
be used with different configurations that stresses the scenario.

A test name can have any name. A common use case is simply to compare
kernel versions but it can be anything --different compiler, different
userspace package, different benchmark configuration etc.

Monitors can be optionally configured, but care should be taken as there
is a possibility that they introduce overhead of their own.
Hence, for some performance sensitive tests it is preferable to have no
monitoring.

Many of the tests download external benchmarks. An attempt will be made
to download from a mirror if it exists. To get an idea where the mirror
should be located, grep for `MIRROR_LOCATION=` in `shellpacks/`.

A basic invocation of the suite is

```
$ ./bin/autogen-configs
$ ./run-mmtests.sh --no-monitor --config configs/config-pagealloc-performance 5.8-vanilla
$ ./run-mmtests.sh --no-monitor --config configs/config-pagealloc-performance 5.9-vanilla
$ cd work/log
$ ../../compare-kernels.sh
$ mkdir /tmp/html/
$ ../../compare-kernels.sh --format html --output-dir /tmp/html > /tmp/html/index.html
```

The first step is optional. Some configurations are auto-generated from
a template, particularly the filesystem-specific ones.

Note that `List::BinarySearch` may need to be installed from cpan for the
reporting to work. Similarly, `R` should be installed if attempting to
highlight whether performance differences are statistically relevant.

# Running Benchmarks with MMTests

## Configuration

All available configurations are stored in `configs/`.

The config file can take many options, in the form of `export`-ed
variables. There is an example (functional) config file available in
[`config`](https://github.com/gormanm/mmtests/blob/master/config).

Some options are universal, others are specific to the test.
Some of the universal ones are:

* `MMTESTS`:
	A list of what tests will be run.
* `AUTO_PACKAGE_INSTALL`:
	Whether packages necessary for building or running benchmarks
	should be automatically installed, without asking any confirmation
	(takes a `yes` or `no` and creating a `/.mmtests-auto-package-install`
	would be equivalent of setting this to `yes`).
* `MMTESTS_NUMA_POLICY`:
	Whether `numad` or `numactl` should be used for deciding (typically,
	for restricting) on what CPUs and/or NUMA nodes the benchmark will run.
	It accepts several values. `none`, `numad` or `interleave`, are
	the simplest, but the following ones can also be used:
	* `fullbind_single_instance_node`
	* `fullbind_single_instance_cpu`
	* `membind_single_instance_node`
	* `cpubind_single_instance_node`
	* `membind_single_instance_node`
	* `membind_single_instance_node`
	* `cpubind_largest_nonnode0_memory`, in which case, `MMTESTS_NODE_ID`
	should also be defined
	* `cpubind_node_nrcpus`, in which case `MMTESTS_NUMA_NODE_NRCPUS`
	should also be defined.
	If `none` is used or the option is not present, nothing is done
	in terms of NUMA pinning of the benchmarks.
* `MMTESTS_TUNED_PROFILE`:
	Whether or not the [tuned](https://tuned-project.org/) tool should
	be used and, if yes, with which profile. In fact, the option takes
	the name of the desired profile (which should be present in the
	system. If this is defined `tuned` is started and stopped around
	the execution of the benchmarks.
* `SWAP_CONFIGURATION`, `SWAP_PARTITIONS`, `SWAP_SWAPFILE_SIZEMB`:
	It's possible to use a different swap configuration than what is
	provided by default.
* `TESTDISK_RAID_DEVICES`, `TESTDISK_RAID_MD_DEVICE`, `TESTDISK_RAID_OFFSET`,
`TESTDISK_RAID_SIZE`, `TESTDISK_RAID_TYPE`:
	If the target machine has partitions suitable for configuring RAID,
	they can be specified here. This RAID partition is then used for
	all the tests.
* `TESTDISK_PARTITION`:
	Use this partition for all tests.
* `TESTDISK_FILESYSTEM`, `TESTDISK_MKFS_PARAM`, `TESTDISK_MOUNT_ARGS`:
	The filesystem, `mkfs` parameters and mount arguments for the test
	partitions.
* `TESTDISK_DIR`:
	A directory passed to the test. If not set, defaults to
	`SHELLPACK_TEMP`. The directory is supposed to contain a precreated
	environment (eg. a specifically created filesystem mounted with desired
	mount options).
* `STORAGE_CACHE_TYPE`, `STORAGE_CACHING_DEVICE`, `STORAGE_BACKING_DEVICE`:
	It's also possible to use storage caching.
	`STORAGE_CACHE_TYPE` is either "dm-cache" or "bcache". The devices
	specified with `STORAGE_CACHING_DEVICE` and `STORAGE_BACKING_DEVICE`
	are used to create the cache device which then is used for all the
	tests.

## Monitoring

A full list of available monitors is in `monitors/`.

The following options, to be defined in the config file, can be used to
control monitoring:

* `RUN_MONITOR`:
	`yes` or `no` switch for deciding whether monitoring should happen or
	not, during the execution of the benchmarks. If set to `no`, even if
	monitors are defined, they will be ignored (but see `MONITOR_ALWAYS`
	below). It can be overridden by the `--run-monitors` and `--no-monitor`
	command like parameters. I.e., `--run-monitors` means we will always
	run monitors, even if we have `RUN_MONITOR=no` in the config file
	(and vice versa, for `--no-monitor` and `RUN_MONITOR=yes`).
* `MONITORS_ALWAYS`:
	Basically, another override. In fact, monitors defined here will be
	started even if we and `RUN_MONITOR=no` and/or `--no-monitor`.
* `MONITORS_GZIP`:
	A list of monitors to be used during the benchmarks. Their output
	will be saved in compressed (with gzip) log files.
* `MONITORS_WITH_LATENCY`:
	A list of monitors to be used during the benchmarks with their output
	augmented with some additional timestamping.
* `MONITOR_UPDATE_FREQUENCY`:
	How frequently, in seconds, the various defined monitors should
	produce and log a sample.
* `MONITOR_FTRACE_OPTIONS`, `MONITOR_FTRACE_EVENTS`:
	respectively, options to set and tracing events to enable for `ftrace`,
	if the "ftrace" monitor is enabled.
* `MONITOR_PERF_EVENTS`:
	list of `perf` events to [stat](https://man7.org/linux/man-pages/man1/perf-stat.1.html)
	or [record](https://man7.org/linux/man-pages/man1/perf-record.1.html),
	when any of the	"perf-foo" monitor is enabled (see below).

The files in `monitors/` all follow the same naming scheme, which is
`watch-foo.[sh|pl]`. For instance, we have `monitors/watch-mpstat.sh`,
`monitors/watch-proc-interrupts.sh` `monitors/watch-proc-vmstat.sh`. For
monitoring the output of `mpstat` and the content of `/proc/interrupts` and
`/proc/vmstat` during the execution of a benchmark, include this option in
to the config file: `MONITORS_GZIP="proc-vmstat mpstat proc-interrupts"`

Similarly, to monitor the output of `vmstat` and `iostat`, and also add
some timestamps to the output, define this option:
`MONITORS_WITH_LATENCY="vmstat iostat"`.

In order to record the output of, for instance, the `sched_migrate_task`
tracepoint, make sure to have `ftrace` in the list of monitors defined in
`MONITORS_GZIP` and then add
`MONITOR_FTRACE_EVENTS="sched/sched_migrate_task"`.
(See also [`configs/config-monitor-vm-stalls`](https://github.com/gormanm/mmtests/blob/master/configs/config-monitor-vm-stalls)
for a more advanced example.)

For using `perf` "as a monitor", a list of events should be defined, e.g.
`MONITOR_PERF_EVENTS=cpu-migrations,context-switches` or
`MONITOR_PERF_EVENTS=node-load-misses,node-store-misses`. Also, the monitor
should be defined either adding `perf-time-stat` to the list of
`MONITORS_GZIP`, or adding `perf-event-stat` to the `MONITORS_TRACER` option.

## Reporting

For reporting, there is a basic `compare-kernels.sh script`. It can
optionally specify a different baseline and comparison point. By default,
table is organised by the time the test was executed.

# MMTests Internal Structure & Development

## Benchmarks & Shellpacks

The install and test scripts are automatically generated from template
files stored in `shellpack_src/src/`. Some have a build suffix indicating
that it is only building a supporting tool like a library a benchmark
requires. *Do not modify* the generated test-scripts in `shellpacks/` directory
as they will simply be overwritten.

As MMTests downloads a number of benchmarks it is possible to create
a local mirror. The location of the mirror is configured in `WEBROOT` in
`shellpacks/common-config.sh`.  For example, `kernbench` tries to download
`$WEBROOT/kernbench/linux-3.0.tar.gz`. If this is not available, it is
downloaded from the Internet. This can add delays in testing and consumes
bandwidth so is worth configuring.

## Contributing and Bug Reporting

Patches should be sent to Mel Gorman [\<mgorman@techsingularity.net\>](mailto:mgorman@techsingularity.net).
While the project is hosted on [github](https://github.com/gormanm/mmtests),
notifications get lost so pull requests there may be missed for quite a
long time.

# References

(Pseudo-)Random links to when MMTests got mentioned around in the Internet:

* MMTests being used to benchmark patches to the task wake-up path
  inside the Linux scheduler, on LKML
  [here](https://lore.kernel.org/lkml/45cce983-79ca-392a-f590-9168da7aefab@arm.com/)
  and [here](https://lore.kernel.org/lkml/7dd00a98d6454d5e92a7d9b936d1aa1c@hisilicon.com/).
* MMTests used to reproduce a bug in the accounting code inside
  the Linux scheduler, on
  [LKML](https://lore.kernel.org/lkml/20201116171641.GU3371@techsingularity.net/).
* MMTests used to benchmark some early version of the Core Scheduling patches,
  highlighting their impact on both baremetal and virtualization workloads,
  on [LKML](https://lore.kernel.org/lkml/277737d6034b3da072d3b0b808d2fa6e110038b0.camel@suse.com/)
  (check the replies for seeing all the benchmark results).
* Additionally to the above examples, a lot more reports of MMTests being
  used for Linux kernel development can be found just by searching for
  'MMTests' in an [LKML archive](https://lore.kernel.org/lkml/?q=mmtests).
* Giovanni Gherdovich explaining running MMTests and reading the
  reporting on [LKML](https://lkml.org/lkml/2018/12/8/55).

Talks and presentation about or related to MMTests:

* [Scheduler benchmarking with MMTests](https://lwn.net/Articles/820823/)
  is a report of a talk about MMTests given at 2020 OSPM conference
  ([slides](https://static.lwn.net/images/conf/2020/ospm/faggioli-mmtests.pdf)).
* FOSDEM 2020 talk about MMTests, focusing on using it for running
  benchmarks inside virtual machines
  [Automated Performance Testing for Virtualization with MMTests](https://archive.fosdem.org/2020/schedule/event/testing_automated_performance_testing_virtualization/)
* Mel Gorman's talk at SUSE Labs Conference 2018,
  [Marvin: Automated assistant for development and CI](https://www.youtube.com/watch?v=jOnIQJQzW3s).
  It's about [Marvin](http://techsingularity.net/blog/?p=5),
  but mentions MMTests as well.
* Davidlohr's talk at LinuxCon NA 2015
  [Performance Monitoring in the Linux Kernel](https://lccocc2015.sched.com/event/3XhH/performance-monitoring-in-the-linux-kernel-davidlohr-bueso-suse)

Some historic references:
* [MMTests 0.05](https://marc.info/?l=linux-mm&m=134702176004919&w=2)
* [MMTests 0.03 & 0.04](https://lwn.net/Articles/502747/)
* [MMTests 0.02](https://lwn.net/Articles/463339/)
* [MMTests 0.01](https://lwn.net/Articles/454121/)
