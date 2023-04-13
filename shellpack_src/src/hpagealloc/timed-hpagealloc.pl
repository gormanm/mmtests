#!/usr/bin/perl
# Script to time hugepage allocations

use strict;
use Time::HiRes qw( time usleep );
use File::Slurp;
use Try::Tiny;

my $hpage_size = 2048;
my $nr_alloc = 100;
my $nr_stride = 10;
my $alloc_timeout = 600;

if ($ARGV[0] ne "") {
	$nr_alloc = $ARGV[0];
}

if ($ARGV[1] ne "") {
	$nr_stride = $ARGV[1];
}

if ($ARGV[2] ne "") {
	$hpage_size = $ARGV[2];
}

# Read available hugepages
my $hpage_root = "/sys/kernel/mm/hugepages";
opendir(my $dh, $hpage_root) || die "Huge pages not supported by system";
my @hpage_dirs = grep { /hugepages/ && -d "$hpage_root/$_" } readdir($dh);
closedir $dh;

# Ensure requested hugepage size is supported
my @hpage_sizes = map { s/[a-zA-Z-]//gr } @hpage_dirs;
my $hpage_dir = "";
foreach my $size (@hpage_sizes) {
	if ($size == $hpage_size) {
		$hpage_dir = "$hpage_root/hugepages-${size}kB";
		last;
	}
}
my $hpage_tunable = "$hpage_dir/nr_hugepages";
die("Huge page size $hpage_size is not available") if $hpage_dir eq "";
die("Huge page cannot be allocated via $hpage_tunable") if ! -f $hpage_tunable;

# Check nr_hugepages is already 0
my $nr_hugepages = read_file($hpage_tunable);
chomp($nr_hugepages);
die("$nr_hugepages are already allocated") if $nr_hugepages > 0;

# Allocated the requested number of pages in batches
STDOUT->autoflush(1);
while ($nr_hugepages < $nr_alloc) {
	my $attempt = $nr_alloc - $nr_hugepages, $nr_stride;
	$attempt = $nr_stride if $nr_stride < $attempt;

	# Prepare to allocate the batch
	my $start_time = time;
	my $actual_hugepages = $nr_hugepages;
	my $elapsed = 0;
	my $target_hugepages = $nr_hugepages + $attempt;
	my $nr_failed = 0;

	while ($actual_hugepages < $target_hugepages && $elapsed < ($alloc_timeout / ($nr_failed+1))) {
		write_file($hpage_tunable, { err_mode => 'quiet'}, $target_hugepages);
		$actual_hugepages = read_file($hpage_tunable);
		if ($actual_hugepages - $nr_hugepages == 0) {
			if ($nr_failed < 10) {
				$nr_failed++;
			}
		} else {
			$nr_failed = 0;
		}
		chomp($actual_hugepages);
		$elapsed = time - $start_time;
	}
	my $nr_success = $actual_hugepages - $nr_hugepages;

	chomp($nr_hugepages);
	my $elapsed_ms = $elapsed * 1000;
	printf "%-4d %-4d %-d %12.4f %12.4f\n", $actual_hugepages, $nr_alloc, $nr_success, $elapsed_ms, $nr_success > 0 ? $elapsed_ms / $nr_success : $elapsed_ms;
	last if $elapsed >= $alloc_timeout;
	last if $nr_success == 0;
	$nr_hugepages = $actual_hugepages;
}

write_file($hpage_tunable, { err_mode => 'quiet'}, 0)
