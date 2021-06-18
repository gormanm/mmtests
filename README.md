# Overview

MMTests is a configurable test suite that runs performance tests
against arbitrary workloads. This is not the only test framework
but care is taken to make sure the test configurations are accurate,
representative and reproducible. Reporting and analysis is common across
all benchmarks. Support exists for gathering additional telemetry while
tests are running and hooks exist for more detailed tracing using
[ftrace](https://www.kernel.org/doc/html/latest/trace/ftrace.html)
or [perf](https://perf.wiki.kernel.org/).

# Organisation

The top-level directory has a single driver script called `run-mmtests.sh`
which reads a config file that describes how the benchmarks should be
configured and executed. In some cases, the same benchmarking tool may
be used with different configurations that stresses the scenario.

A test name can have any name. A common use case is simply to compare
kernel versions but it can be anything --different compiler, different
userspace package, different benchmark configuration etc.

Monitors can be optionally configured. A full list is in `monitors/`.
Care should be taken with monitors as there is a possibility that they
introduce overhead of their own.  Hence, for some performance sensitive
tests it is preferable to have no monitoring.

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

# Configuration

The config file can take many options. Some are universal, others are
specific to the test.

* `MMTESTS`:
	A list of what tests will be run
* `SWAP_CONFIGURATION`, `SWAP_PARTITIONS`, `SWAP_SWAPFILE_SIZEMB`:
	It's possible to use a different swap configuration than what is
	provided by default.
* `TESTDISK_RAID_DEVICES`, `TESTDISK_RAID_MD_DEVICE`, `TESTDISK_RAID_OFFSET`,
`TESTDISK_RAID_SIZE`, `TESTDISK_RAID_TYPE`:
	If the target machine has partitions suitable for configuring RAID,
	they can be specified here. This RAID partition is then used for
	all the tests
* `TESTDISK_PARTITION`:
	Use this partition for all tests
* `TESTDISK_FILESYSTEM`, `TESTDISK_MKFS_PARAM`, `TESTDISK_MOUNT_ARGS`:
	The filesystem, `mkfs` parameters and mount arguments for the test
	partitions
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

As MMTests downloads a number of benchmarks it is possible to create
a local mirror. The location of the mirror is configured in `WEBROOT` in
`shellpacks/common-config.sh`.  For example, `kernbench` tries to download
`$WEBROOT/kernbench/linux-3.0.tar.gz`. If this is not available, it is
downloaded from the internet. This can add delays in testing and consumes
bandwidth so is worth configuring.

## Organisation

All available configurations are stored in `configs/`.

The install and test scripts are automatically generated from template
files stored in `shellpack_src/src/`. Some have a build suffix indicating
that it is only building a supporting tool like a library a benchmark
requires. *Do not modify* the generated test-scripts in `shellpacks/` directory
as they will simply be overwritten.

# Reporting

For reporting, there is a basic `compare-kernels.sh script`. It can
optionally specify a different baseline and comparison point. By default,
table is organised by the time the test was executed.

# Development

Patches should be sent to Mel Gorman [\<mgorman@techsingularity.net\>](mailto:mgorman@techsingularity.net).
While the project is hosted on [github](https://github.com/gormanm/mmtests),
notifications get lost so pull requests there may be missed for quite a
long time.
