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

Note that [`List::BinarySearch`](https://metacpan.org/pod/List::BinarySearch)
and maybe even [`Math::Gradient`](https://metacpan.org/pod/Math::Gradient) may
need to be installed from [CPAN](https://www.cpan.org/) for the reporting to
work. Similarly, [`R`](https://www.r-project.org/) should be installed if
attempting to highlight whether performance differences are statistically
relevant.

# Running Benchmarks with MMTests

## Configuration

All available configurations are stored in `configs/`.

For example `config-pagealloc-performance` can be used to run tests that
may be able to identify performance regressions or gains in the page allocator.
Similarly there are network, disk and scheduler configs.

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

### Platform Specific Configuration

It is possible to retrieve information about the characteristics of the system
where the benchmarks will be running, and use them inside a config file.

For instance:
* `MEMTOTAL_BYTES`:
	Tells how much memory there is in the system.
* `NUMCPUS`:
	Tells how many CPUs are present in the system.

It is possible to add the following to the config file:

```
. $SHELLPACK_INCLUDE/include-sizes.sh
get_numa_details
```

This will give access to more information about the system topology, such as:
* `NUMLLCS`:
	Number of Last Level Caches present in the system.
* `NUMNODES`:
	Number of NUMA nodes.

Taking advantage of this knowledge about the characteristics of the platform
the configuration of the benchmarks can be refined.

For an example check
[config-workload-stream-omp-llcs](https://github.com/gormanm/mmtests/blob/master/configs/config-workload-stream-omp-llcs), where this is done: `STREAM_THREADS=$NUMLLCS`. Or
[config-scheduler-schbench](https://github.com/gormanm/mmtests/blob/master/configs/config-scheduler-schbench),
which has: `SCHBENCH_THREADS=$(((NUMCPUS/NUMNODES)-1))`

## Running Benchmarks

The entry point to running benchmarks is  `run-mmtests.sh`. If run with `-h`
or `--help` the available options are shown:

```
 run-mmtests [-mnpb] [-c config-file] test-name

  Options:
  -m|--run-monitors         Run with monitors enabled as specified by the configuration
  -n|--no-monitor           Only execute the benchmark, do not execute it
  -p|--performance          Set the performance cpufreq governor before starting
  -c|--config               Configuration file to read (default: config)
  -b|--build-only           Only build the benchmark, do not execute it
```

If no config file is specified, the one in `./config` is used.

After a run, the benchmark results as well as any data that can be useful for
a report will be available in the `work/log` directory. (more specifically,
in `work/log/TEST_RUN/iter-0`, for a run called `TEST_RUN`).

Note that often a configuration will run more than just one single benchmark
(this depends on the value of the `MMTESTS` option in the config itself),
resulting in some subdirectories being present in the results directory.

### Running MMTests as `root`

Configuring the system for running a benchmark may include doing some changes
to the system itself that can only be done with `root` provileges.

For instance, the [config-workload-thpfioscale-defrag](https://github.com/gormanm/mmtests/blob/master/configs/config-workload-thpfioscale-defrag)
config does:

```
echo always > /sys/kernel/mm/transparent_hugepage/defrag
```

If starting `run-mmtests.sh` as a "regular user" doing something like that
will fail. benchmarks should still complete (most likely with some warnings)
but results will likely **not** be the ones expected.

In fact, MMTests is intended to be run as `root`. For most of the changes that
it applies to the system, the framework is careful to (try to) undo them. It
is however fair to say that MMTests is best used on machines that can be
redeployed and reset to a clean known state both before and after running a
benchmark.

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

### Reporting with `compare-kernel.sh`

For reporting, there is a basic `compare-kernels.sh script`.

Despite the name, it can compare an arbitrary number of benchmarking runs.
The name has historical reasons, from the time when the only use case was
comparing kernel versions, but nowadays anything can be compared --machines,
userspace packages, benchmark versions, tuning parameters etc.

It is optionally possible to specify a different baseline and comparison points,
while by default the results are organised by the time the test was executed.

```
NAME
    compare-kernels.sh - Compare results between benchmarking runs

SYNOPSIS
    compare-kernels.sh [options]

     Options:
      --baseline <testname>         Baseline test name, default is time ordered
      --compare  "<test> <test>"    Comparison test names, space separated
      --exclude  "<test> <test>"    Exclude test names
      --auto-detect                 Attempt to automatically highlight significant differences
      --sort-version                Assume kernel versions for test names and attempt to sort
      --format html                 Generate a HTML format of the report
      --output-dir                  Output directory for HTML report
```

It must be run from within an MMTests results directory. So, even if the
benchmarks have been run on a different machine, it is enought to capture
`work/log` and run `compare-kernels.sh` from there.

In the table(s) produced, it is usually the most interesting to look at the
average values, computed over the individual results of multiple repetitions
of the benchmarks. Note that some benchmarks use the harmonic mean
([Hmean](https://en.wikipedia.org/wiki/Harmonic_mean)) and some use the
arithmetic mean ([Amean](https://en.wikipedia.org/wiki/Arithmetic_mean)),
depending of the nature of the results.

`compare-kernel.sh` can generate an HTML report, with both tables and graphs.
For doing that, both the format and the output directory needs to be
specified. The HTML page will them come directly out of the standard output
of the tool. Therefore, invoking it like this is recommended:

```
$ cd work/log
$ mkdir /tmp/report
$ ../../compare-kernels.sh --format html --output-dir /tmp/report > /tmp/report/index.html
```

### Reporting with `compare-mmtestsl.pl`

It is possible to obtain a report using a different tool. It is the script
that `compare-kernels.sh` calls internally and it located at
`bin/compare-mmtests.pl`.

The output is the same table(s) produced by `compare-kernels.sh`.

A possible invocation could look like this:

```
./bin/compare-mmtests.pl --directory work/log --benchmark stream --names TEST_RUN,TEST_RUN_BUSY
                           TEST_RUN          TEST_RUN_BUSY
MB/sec copy     19059.86 (   0.00%)    15234.88 ( -20.07%)
MB/sec scale    14078.10 (   0.00%)    11258.38 ( -20.03%)
MB/sec add      14740.32 (   0.00%)    11749.84 ( -20.29%)
MB/sec triad    14504.22 (   0.00%)    11317.26 ( -21.97%)
```

If the benchmark does multiple operations --like STREAM above that checks the
memory throughput of four different operations-- there will be one result for
each. In these cases, `compare-mmtests.pl` can be used to produce an *overall*
comparison between the benchmarks.

This is done by taking the geometric mean ([Gmean](https://www.cs.virginia.edu/stream/)
of the results. The geometric mean is chosen because it has the nice property
that the  mean of ratios is equal to the ratios of the means, so we do not get
different results depending on the order of the operations.

Looking at the Gmean offers a concise and hence rather useful overview
of the overall performance, especially when complex benchmarks are used.

For instance:
```
./bin/compare-mmtests.pl --directory work/log/ --benchmark stream --names TEST_RUN,TEST_RUN_BUSY --print-ratio
                          TEST_RUN          TEST_RUN_BUSY
Ratio copy         1.00 (0.00%) (NaNs)        0.80 (-20.07%) (NaNs)
Ratio scale        1.00 (0.00%) (NaNs)        0.80 (-20.03%) (NaNs)
Ratio add          1.00 (0.00%) (NaNs)        0.80 (-20.29%) (NaNs)
Ratio triad        1.00 (0.00%) (NaNs)        0.78 (-21.97%) (NaNs)
Gmean Higher        1.00                         0.79
```

Of course, the Gmean for the benchmark chosen as the baseline will always
be `1.00`. Additionally, the `Higher` or `Lower` "tag" tells us whether
it is the higher or lower values that represent better performance.

In the example above, `TEST_RUN_BUSY` reaches only the 79% of `TEST_RUN`
performance, which means that it is 21% slower.

Further info about reporting:

* [Performance Analysis and Regression Detection in MMTests](docs/regression-detection.md)

# MMTests Internal Structure & Development

## Benchmarks & Shellpacks

The install and test scripts are automatically generated from "shellpacks".
A shellpack is a pair of benchmark and install scripts that are stored in
`shellpacks/`.

Actual shellpacks are automatically generated from template files stored
in `shellpack_src/src/`. Some have a build suffix indicating that it is only
building a supporting tool like a library a benchmark requires. *Do not
modify* the generated test-scripts in `shellpacks/` directory as they will
simply be overwritten.

For instance, `/shellpacks/shellpack-bench-pgbench` --which will be
automatically generated from `shellpack_src/src/pgbench/pgbench-bench`--
contains all the individual test steps.

Each test is driven by `bin/run-single-test.sh` script which reads
the relevant `drivers/driver-<testname>.sh` script (e.g.,
`drivers/driver-pgbench.sh`).

## Downloading Benchmarks & Mirrors

MMTests needs to download the various benchmarks from their official location,
i.e., from the Internet. That might be problematic because it can (should!) be
considered not trusted, or even just because the official version may have been
updated to a newer version which maybe is not yet compatible with the current
version of MMTests' shellpacks for that particular benchmark. And if this
happens, the run will likely fail.

Other potential problems are that the download may fail due to temporary
networking issues, that it consumes bandwidth and that it adds delays and
makes testing longer.

It is therefore possible to create a local mirror. The location of such mirror
can be configured in `WEBROOT` in `shellpacks/common-config.sh`.

For example, `kernbench` tries to download `$WEBROOT/kernbench/linux-3.0.tar.gz`.
If this is not available, it is downloaded from the internet.
This can add delays in testing and consumes bandwidth so is worth configuring.

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
