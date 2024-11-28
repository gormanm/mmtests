# SPDX-License-Identifier: GPL-2.0-or-later OR copyleft-next-0.3.1
#
# Stat.pm
#
# Basic stats module
#
# Copyright (c) 2002-2024 Mel Gorman <mgorman@techsingularity.net>
# Copyright (c) 2017-2019 Jan Kara <jack@suse.cz>
# Copyright (c) 2017-2023 Andreas Herrmann <aherrmann@suse.de>
# Copyright (c) 2024 Luis Chamberlain <mcgrof@kernel.org>

package MMTests::Stat;
require Exporter;
use vars qw (@ISA @EXPORT);
use MMTests::Report;
use strict;
use feature 'signatures';
no warnings 'experimental::signatures';
use POSIX qw(floor);
use FindBin qw($Bin);
use Scalar::Util qw(looks_like_number);

@ISA    = qw(Exporter);
@EXPORT = qw(&calc_welch_test &pdiff &pndiff &rdiff &sdiff &cidiff &calc_sum
	     &calc_min &calc_max &calc_range &select_lowest &select_highest
	     &calc_amean &select_trim &calc_geomean &calc_hmean &calc_median
	     &calc_coeffvar &calc_stddev &calc_quartiles &calc_submean_ci
	     &stat_compare &calc_samplespct &data_valid);

# This defines function to use for comparison of a particular statistic
# (computed by calc_xxx function). If the statistic does not have comparison
# function defined, base the comparison function on preferred value.
use constant stat_compare => {
	"stddev" => "pndiff",
	"coeffvar" => "pndiff",
	"submeanci" => "pndiff",
	"samples" => "pdiff",
};

# Names of statistic functions for summarization titles
use constant stat_names => {
	"min"		=> "Min",
	"max"		=> "Max",
	"amean"		=> "Amean",
	"amean-sub"	=> "SubAmean",
	"amean-"	=> "BAmean-%d",
	"hmean"		=> "Hmean",
	"hmean-sub"	=> "SubHmean",
	"hmean-"	=> "BHmean-%d",
	"stddev"	=> "Stddev",
	"coeffvar"	=> "CoeffVar",
	"percentile-25" => "1st-qrtle",
	"percentile-50" => "2nd-qrtle",
	"percentile-75" => "3rd-qrtle",
	"percentile-90" => "Max-90",
	"percentile-95" => "Max-95",
	"percentile-99" => "Max-99",
	"percentile-99.9" => "Max-99.9",
	"percentile-99.99" => "Max-99.99",
	"percentile-99.999" => "Max-99.999",
	"percentile-99.9999" => "Max-99.9999",
	"percentile-99.99999" => "Max-99.99999",
	"percentile-"	=> "Max-%d",
	"samples"	=> "Samples",
	"samples-"	=> "Samples-[%s)",
	"samplespct-"	=> "Samples%%-[%s)",
	"submeanci"	=> "SubmeanCI",
};

# Print the percentage difference between two values
sub pdiff {
	if ($_[0] == $_[1] || $_[0] == 0) {
		return 0;
	}

	if ($_[1] == 0 || $_[1] eq "NaN") {
		return 100;
	}

	return $_[0] * 100 / $_[1] - 100;
}

sub pndiff {
	if ($_[0] == $_[1]) {
		return 0;
	}

	if ($_[0] == 0) {
		return 100;
	}
	if ($_[1] == 0 && $_[0] != 0) {
		return -99;
	}
	return 100 - ($_[0] * 100 / $_[1]);
}

sub rdiff {
	if ($_[1] == 0 || $_[1] eq "NaN") {
		return 0;
	}
	if ($_[0] == 0 || $_[0] eq "NaN") {
		return 1;
	}
	return $_[0] / $_[1];
}

sub sdiff {
	my ($new, $newstddev, $base, $basestddev) = @_;
	my $diff = $new - $base;
	my $pdev = sqrt(($newstddev**2 + $basestddev**2) / 2);

	if ($pdev == 0) {
		return $diff;
		# Typically, this occurs for little integers under 20
		# and here we want to see if anything changes so issuing
		# quite high numbers (directly the difference).
	} else {
		return $diff / $pdev;
	}
}

sub cidiff {
	my ($new, $newci, $base, $baseci) = @_;
	my $diff = $new - $base;
	my $cisum = $newci + $baseci;

	if ($cisum == 0) {
		return $diff;
	}
	return $diff / $cisum;
}

sub calc_sum {
	my $dataref = shift;

	if (! defined $dataref->[0]) {
		return "NaN";
	}

	my $sum = 0;
	foreach my $value (@{$dataref}) {
		$sum += $value;
	}

	return $sum;
}

sub calc_min {
	my ($dataref, $statsref) = @_;
	my $elements = @{$dataref};
	my $min;

	if (!defined($dataref->[0])) {
		$min = "NaN";
	} elsif (defined($$statsref->{data_ascending})) {
		$min = $dataref->[0];
	} elsif (defined($$statsref->{data_descending})) {
		$min = $dataref->[$elements - 1];
	} else {
		$min = $dataref->[0];
		foreach my $value (@{$dataref}) {
			if ($value < $min) {
				$min = $value;
			}
		}
	}

	return $min;
}

sub calc_max {
	my ($dataref, $statsref) = @_;
	my $elements = @{$dataref};
	my $max;

	if  (!defined($dataref->[0])) {
		$max = "NaN";
	} elsif (defined($$statsref->{data_ascending})) {
		$max = $dataref->[$elements - 1];
	} elsif (defined($$statsref->{data_descending})) {
		$max = $dataref->[0];
	} else {
		$max = $dataref->[0];
		foreach my $value (@{$dataref}) {
			if ($value > $max) {
				$max = $value;
			}
		}
	}

	return $max;
}

sub calc_range {
	my $dataref = shift;

	if (! defined $dataref->[0]) {
		return "NaN";
	}

	return calc_max($dataref) - calc_min($dataref);
}

sub calc_amean {
	my ($dataref, $statsref) = @_;
	my $sum = 0;
	my $n = 0;
	my $elements = @{$dataref};
	my $i;
	my $mean;

	for ($i = 0; $i < $elements; $i++) {
		if (defined($dataref->[$i])) {
			$sum += $dataref->[$i];
			$n++;
		}
	}

	if ($n == 0) {
		$mean = "NaN";
	} else {
		$mean = $sum / $n;
	}

	if (defined($$statsref->{save_stats})) {
		$$statsref->{amean} = $mean;
	}

	return $mean;
}

sub calc_geomean {
	my $dataref = shift;
	my $mult = 1;
	my $n = 0;
	my $elements = @{$dataref};
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $dataref->[$i]) {
			$mult *= $dataref->[$i];
			$n++;
		}
	}

	if ($n == 0) {
		return "NaN";
	}
	return $mult**(1/$n);
}

sub calc_hmean {
	my ($dataref, $statsref) = @_;
	my $sum = 0;
	my $n = 0;
	my $elements = @{$dataref};
	my $i;
	my $mean;

	for ($i = 0; $i < $elements; $i++) {
		if (defined($dataref->[$i])) {
			if ($dataref->[$i] > 0) {
				$sum += 1/$dataref->[$i];
				$n++;
			} else {
				$n = "NaN";
				last;
			}
		}
	}

	if ($n == 0) {
		$mean = "NaN";
	} else {
		$mean = $n/$sum;
	}

	if (defined($$statsref->{save_stats})) {
		$$statsref->{hmean} = $mean;
	}

	return $mean;
}

sub calc_median {
	my $dataref = shift;
	my $nr_elements = @{$dataref};
	my $mid = int $nr_elements / 2 - 1;

	my @sorted = sort { $a <=> $b } @{$dataref};
	if ($nr_elements % 2 == 0) {
		return $sorted[$mid];
	} else {
		return ($sorted[$mid-1] + $sorted[$mid])/2;
	}
}

sub select_data {
	my ($low, $high, $dataref) = @_;
	my $len = @{$dataref};

	if ($low < 0) {
		$low = 0;
	}
	if ($high >= $len) {
		$high = $len - 1;
	}
	if (($low <= 0 && $high >= $len) ||
	    ($low > $high)) {
		return $dataref;
	}

	my @sorted = sort { $a <=> $b } @{$dataref};
	my @trimmed = @sorted[$low..$high];

	return \@trimmed;
}

sub select_trim {
	my ($percentage, $dataref) = @_;
	my $nr_elements = @{$dataref};
	my $nr_trim = int ($nr_elements - int ($nr_elements * $percentage / 100)) / 2;

	return select_data($nr_trim, $nr_elements - $nr_trim, $dataref);
}

sub select_highest {
	my ($percentage, $dataref) = @_;
	my $nr_elements = @{$dataref};
	my $nr_trim = int ($nr_elements * $percentage / 100);

	return select_data($nr_elements - $nr_trim - 1, $nr_elements - 1, $dataref);
}

sub select_lowest {
	my ($percentage, $dataref) = @_;
	my $nr_elements = @{$dataref};
	my $nr_trim = int ($nr_elements * $percentage / 100);

	return select_data(0, $nr_trim - 1, $dataref);
}

sub calc_stddev {
	my ($dataref, $statsref) = @_;
	my $n = 0;
	my $elements = @{$dataref};
	my $diff;
	my $i;
	my $mean;
	my $stddev;

	$mean = defined($$statsref->{amean}) ? $$statsref->{amean} :
	    (calc_amean($dataref, $statsref));
	if ($mean eq "NaN") {
		$stddev = "NaN";
	} else {
		for ($i = 0; $i < $elements; $i++) {
			if (defined $dataref->[$i]) {
				$diff += ($dataref->[$i] - $mean) ** 2;
				$n++;
			}
		}

		if ($n <= 1) {
			$stddev = "NaN";
		} else {
			$stddev = sqrt($diff / ($n - 1));
		}
	}

	if (defined($$statsref->{save_stats})) {
		$$statsref->{stddev} = $stddev;
	}

	return $stddev;
}

sub calc_coeffvar {
	my ($dataref, $statsref) = @_;
	my $mean;
	my $stddev;

	$mean = defined($$statsref->{amean}) ? $$statsref->{amean} :
	    (calc_amean($dataref, $statsref));
	$stddev = defined($$statsref->{stddev}) ? $$statsref->{stddev} :
	    (calc_stddev($dataref, $statsref));

	if ($stddev eq "NaN") {
		$stddev = 0;
	}

	if ($mean eq "NaN") {
		$mean = 0;
	}

	if ($mean) {
		return ($stddev * 100) / $mean;
	} else {
		return 0;
	}
}

sub calc_quartiles {
	my $dataref = shift;
	my @x = sort { $a <=> $b} @{$dataref};
	my @quartiles;
	my $i;

	$quartiles[0] = 0;
	for ($i = 1; $i <= 100; $i++) {
		$quartiles[$i] = $x[int($#x * ($i / 100) + 0.5)];
		chomp($quartiles[$i]);
	}

	return \@quartiles;
}

# Perform Welch's t-test.
# Returns 0 if H_0 is not rejected, returns 1 if H_0 is rejected.
# mean_x, mean_y, stddev_x, stddev_y, n_x, n_y,
# alpha (significance level), e.g. 5 (ie 5%) or 1 (ie 1%)
sub calc_welch_test {
	my $mx = shift;
	my $my = shift;
	my $sx = shift;
	my $sy = shift;
	my $m = shift;
	my $n = shift;
	my $alpha = shift;

	my $tsx = $sx**2 / $m;
	my $tsy = $sy**2 / $n;

	printVerbose("mx: $mx, my: $my, sx: $sx, sy: $sy, m: $m, n: $n, alpha: $alpha%\n");

	# calculate integer used as degrees of freedom
	my $k = ($m - 1) * ($n - 1) * ($tsx + $tsy)**2;
	$k = $k / (($n - 1) * ($tsx)**2 + ($m - 1) * ($tsy)**2);
	$k = floor($k);

	# compute t-value
	my $t = ($mx - $my) / sqrt($tsx + $tsy);

	my $q = qx(echo 'qt(c($alpha / 200), $k, lower.tail = FALSE)' | R --slave);
	$q =~ s/\[1\]|\s//g;

	# reject if |t| > t_{k;(1-alpha/2)}
	if (abs($t) > $q) {
		printVerbose("Rejecting H_0: µx=µy; t=$t, k=$k, qt=$q, alpha=$alpha%\n");
		return 1;
	} else {
		printVerbose("Not rejecting H_0: µx=µy; t=$t, k=$k, qt=$q, alpha=$alpha%\n");
		return 0;
	}
}

# Get reference to data structure, a file with R script, and possible optional
# arguments and pipe the data structure into R script. Return R output as a
# reference to array.
sub pipe_to_R {
	require Cpanel::JSON::XS;
	require IPC::Open2;

	my $dataref = shift;
	my $cmd = "Rscript ".join(" ", @_);
	my $json = Cpanel::JSON::XS->new();
	my @result;

	$json->allow_blessed();
	$json->convert_blessed();

	IPC::Open2::open2(my $readfh, my $writefh, $cmd) || die("Cannot execute R script");
	print $writefh $json->encode($dataref);
	close($writefh);

	while (my $row = <$readfh>) {
		push(@result, $row);
	}
	close($readfh);

	return \@result;
}

sub calc_submean_ci {
	my ($meanName, $dataref) = @_;
	my $resultref;
	my $row;
	my @parsedrow;

	$resultref = pipe_to_R($dataref,
		"$Bin/lib/R/subselection-confidence-interval.R", $meanName);
	$row = @{$resultref}[0];
	@parsedrow = split(' ', $row);
	# Skip initial "[1]" output by R
	return ($parsedrow[1], $parsedrow[2]);
}

sub binsearch_pos_num($target, $aref) {
	die "Only numbers allowed" unless looks_like_number($target);
	die "Expected an array reference!" unless ref $aref eq 'ARRAY';

	my ($low, $high) = (0, scalar @$aref - 1);

	while ($low <= $high) {
		my $mid = int(($low + $high) / 2);
		if ($aref->[$mid] < $target) {
			$low = $mid + 1;
		} elsif ($aref->[$mid] > $target) {
			$high = $mid - 1;
		} else {
			return $mid;
		}
	}

	return $low;
}

# Returns an inclusive range for both, if you only use one return
# value, you consume the last value.
sub binsearch_range_num ($low_target, $high_target, $aref) {
	die "Only numbers allowed" unless looks_like_number($low_target);
	die "Only numbers allowed" unless looks_like_number($high_target);
	die "Expected an array reference!" unless ref $aref eq 'ARRAY';

	my $index_low  = binsearch_pos_num($low_target, $aref);
	my $index_high = binsearch_pos_num($high_target, $aref);

	if($index_high == scalar @$aref or $aref->[$index_high] > $high_target) {
		$index_high--;
	}

	return ($index_low, $index_high);
}

sub calc_samples {
	my ($dataref, $arg) = @_;
	my $elements = @{$dataref};

	# Simple sample count?
	if (!defined($arg)) {
		return $elements;
	}
	# Range specified
	my ($low,$high) = split(',', $arg);

	if ($low eq "min") {
		$low = $dataref->[0];
	} elsif ($high eq "max") {
		$high = $dataref->[$elements - 1];
	}
	my ($lowidx, $highidx) = binsearch_range_num($low, $high, $dataref);
	return $highidx - $lowidx + 1;
}

sub calc_samplespct {
	my ($dataref, $arg) = @_;

	return calc_samples($dataref, $arg) * 100 / scalar(@{$dataref});
}

sub data_valid {
	my $dataref = shift;
	my $elements = @{$dataref};
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (!looks_like_number($dataref->[$i])) {
			return 0;
		}
	}
	return 1;
}

1;
