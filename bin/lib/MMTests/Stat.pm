#
# Stat.pm
#
# Basic stats module

package MMTests::Stat;
require Exporter;
use vars qw (@ISA @EXPORT);
use MMTests::Report;
use strict;
use POSIX qw(floor);
use FindBin qw($Bin);
use List::BinarySearch qw(binsearch_range);

@ISA    = qw(Exporter);
@EXPORT = qw(&calc_welch_test &pdiff &pndiff &rdiff &sdiff &cidiff &calc_sum &calc_min &calc_max &calc_range &calc_true_mean &select_lowest &select_highest &calc_amean &select_trim &calc_geomean &calc_hmean &calc_median &calc_coeffvar &calc_stddev &calc_quartiles &calc_confidence_interval_lower &calc_confidence_interval_upper &calc_submean_ci &stat_compare);

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
	"percentile-"	=> "Max-%d",
	"samples"	=> "Samples",
	"samples-"	=> "Samples-[%s)",
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
	my $dataref = shift;
	my @data = @{$dataref};

	if (! defined $data[0]) {
		return "NaN";
	}

	my $min = $data[0];
	foreach my $value (@data) {
		if ($value < $min) {
			$min = $value;
		}
	}

	return $min;
}

sub calc_max {
	my $dataref = shift;
	my @data = @{$dataref};

	if (! defined $data[0]) {
		return "NaN";
	}

	my $max = $data[0];
	foreach my $value (@data) {
		if ($value > $max) {
			$max = $value;
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
	my $dataref = shift;
	my @data = @{$dataref};
	my $sum = 0;
	my $n = 0;
	my $elements = scalar(@data);
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $data[$i]) {
			if ($data[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
			$sum += $data[$i];
			$n++;
		}
	}

	if ($n == 0) {
		return "NaN";
	}
	return $sum / $n;
}

sub calc_geomean {
	my $dataref = shift;
	my $mult = 1;
	my $n = 0;
	my $elements = @{$dataref};
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $dataref->[$i]) {
			if ($dataref->[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
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
	my $dataref = shift;
	my @data = @{$dataref};
	my $sum = 0;
	my $n = 0;
	my $elements = $#data + 1;
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $data[$i]) {
			if ($data[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
			if ($data[$i] > 0) {
				$sum += 1/$data[$i];
				$n++;
			} else {
				return -1;
			}
		}
	}

	if ($n == 0) {
		return "NaN";
	}
	return $n/$sum;
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

sub calc_true_mean {
	my ($confidenceLevel, $confidenceLimit, $samplesref) = @_;
	my @samples = @{$samplesref};
	my $nr_samples = $#samples;
	my $mean = calc_amean($samplesref);
	my $standardMean = $mean;
	if ($standardMean eq "NaN") {
		return "NaN";
	}

	my $stddev = calc_stddev($samplesref);
	my $conf = calc_confidence_interval_lower("NaN", $confidenceLevel, $samplesref);
	my $limit = $mean * $confidenceLimit / 100;
	my $conf_delta = $mean - $conf; 
	my $usable_samples = $nr_samples;
	my $minSamples = 3;

	
	for (my $sample = 0; $sample <= $nr_samples; $sample++) {

CONF_LOOP:
		while ($conf_delta > $limit) {
			if ($usable_samples == $minSamples) {
				printVerbose("Minimum number of samples reached\n");
				return $standardMean;
			}
			printVerbose("  o confidence delta $conf_delta outside $limit\n");
			my $max_delta = -1;
			my $max_index = -1;
			for ($sample = 0; $sample <= $nr_samples; $sample++) {
				if (! defined $samples[$sample]) {
					next;
				}
				my $delta = abs($samples[$sample] - $mean);
				if ($delta > $max_delta) {
					$max_delta = $delta;
					$max_index = $sample;
				}
			}

			printVerbose("  o dropping index $max_index result $samples[$max_index]\n");
			undef $samples[$max_index];
			$usable_samples--;

			$mean = calc_amean($samplesref);
			$stddev = calc_stddev($samplesref);
			$conf = calc_confidence_interval_lower("NaN", $confidenceLevel, $samplesref);
			$limit = $mean * $confidenceLimit / 100;
			$conf_delta = $mean - $conf;

			printVerbose("  o recalc mean   = $mean\n");
			printVerbose("  o recalc stddev = $stddev\n");
			printVerbose("  o recalc con $confidenceLevel = $conf\n");
			printVerbose("  o limit     = $limit\n");
			printVerbose("  o con delta = $conf_delta\n");
		}
	}

	return calc_amean($samplesref);
}

sub calc_stddev {
	my $dataref = shift;
	my @data = @{$dataref};
	my $n = 0;
	my $elements = $#data + 1;
	my $diff;
	my $i;

	my $mean = calc_amean($dataref);

	for ($i = 0; $i < $elements; $i++) {
		if (defined $data[$i]) {
			if ($data[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
			$diff += ($data[$i] - $mean) ** 2;
			$n++;
		}
	}

	if ($n <= 1) {
		return "NaN";
	}

	return sqrt($diff / ($n - 1));
}

sub calc_coeffvar {
	my $dataref = shift;
	my $stddev = calc_stddev($dataref);
	my $mean = calc_amean($dataref);

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

sub calc_confidence_interval {
	my ($variance, $confidence_level, $dataref) = @_;
	my @data = @{$dataref};
	my $elements = $#data + 1;
	my $n = 0;
	my $i;
	my $stddev;
	my $q; my $q1;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $data[$i]) {
			$n++;
		}
	}

	my $mean = calc_amean($dataref);
	if ($variance !~ /^[-0-9]+/) {
		$stddev = calc_stddev($dataref);
		$q = qx(echo 'qt(c((100 - $confidence_level)/200), $n-1, lower.tail = FALSE)' | R --slave);
		$q =~ s/\[1\]|\s//g;
	} else {
		$stddev = sqrt($variance);
		$q = qx(echo 'qnorm(c((100 - $confidence_level)/200), lower.tail = FALSE)' | R --slave);
		$q =~ s/\[1\]|\s//g;
	}

	return ($q*($stddev/sqrt($n)));
}

sub calc_confidence_interval_lower {
	my ($variance, $confidence_level, $dataref) = @_;
	my $mean = calc_amean($dataref);
	return $mean - calc_confidence_interval($variance, $confidence_level, $dataref);
}

sub calc_confidence_interval_upper {
	my ($variance, $confidence_level, $dataref) = @_;
	my $mean = calc_amean($dataref);
	return $mean + calc_confidence_interval($variance, $confidence_level, $dataref);
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

sub calc_samples {
	my ($dataref, $arg) = @_;
	my @data = @{$dataref};

	# Simple sample count?
	if (!defined($arg)) {
		return scalar(@data);
	}
	# Range specified
	my ($low,$high) = split(',', $arg);

	if ($low eq "min") {
		$low = $data[0];
	} elsif ($high eq "max") {
		$high = $data[$#data];
	}
	my ($lowidx, $highidx) = binsearch_range { $a <=> $b }  $low, $high, @data;
	return $highidx - $lowidx + 1;
}

1;
