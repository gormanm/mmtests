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

@ISA    = qw(Exporter);
@EXPORT = qw(&calc_welch_test &pdiff &pndiff &rdiff &sdiff &cidiff &calc_sum &calc_min &calc_max &calc_range &calc_true_mean &select_lowest &select_highest &calc_mean &select_trim &calc_geomean &calc_harmmean &calc_median &calc_coeffvar &calc_stddev &calc_quartiles &calc_confidence_interval_lower &calc_confidence_interval_upper &calc_submean_ci);

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
	if (! defined $_[0]) {
		return "NaN";
	}

	my $sum = 0;
	foreach my $value (@_) {
		$sum += $value;
	}

	return $sum;
}

sub calc_min {
	if (! defined $_[0]) {
		return "NaN";
	}

	my $min = $_[0];
	foreach my $value (@_) {
		if ($value < $min) {
			$min = $value;
		}
	}

	return $min;
}

sub calc_max {
	if (! defined $_[0]) {
		return "NaN";
	}

	my $max = $_[0];
	foreach my $value (@_) {
		if ($value > $max) {
			$max = $value;
		}
	}

	return $max;
}

sub calc_range {
	if (! defined $_[0]) {
		return "NaN";
	}

	return calc_max(@_) - calc_min(@_);
}

sub calc_mean {
	my $sum = 0;
	my $n = 0;
	my $elements = $#_ + 1;
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			if ($_[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
			$sum += $_[$i];
			$n++;
		}
	}

	if ($n == 0) {
		return "NaN";
	}
	return $sum / $n;
}

sub calc_geomean {
	my $mult = 1;
	my $n = 0;
	my $elements = $#_ + 1;
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			if ($_[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
			$mult *= $_[$i];
			$n++;
		}
	}

	if ($n == 0) {
		return "NaN";
	}
	return $mult**(1/$n);
}

sub calc_harmmean {
	my $sum = 0;
	my $n = 0;
	my $elements = $#_ + 1;
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			if ($_[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
			if ($_[$i] > 0) {
				$sum += 1/$_[$i];
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
	my $nr_elements = @_;
	my $mid = int $nr_elements / 2 - 1;

	my @sorted = sort { $a <=> $b } @_;
	if ($nr_elements % 2 == 0) {
		return $sorted[$mid];
	} else {
		return ($sorted[$mid-1] + $sorted[$mid])/2;
	}
}

sub select_data {
	my ($low, $high, $dataref) = @_;
	my $len = @{$dataref};

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

	return select_data($nr_elements - $nr_trim, $nr_elements, $dataref);
}

sub select_lowest {
	my ($percentage, $dataref) = @_;
	my $nr_elements = @{$dataref};
	my $nr_trim = int ($nr_elements * $percentage / 100);

	return select_data(0, $nr_trim, $dataref);
}

sub calc_true_mean {
	my ($confidenceLevel, $confidenceLimit, @samples) = @_;
	my $nr_samples = $#samples;
	my $mean = calc_mean(@samples);
	my $standardMean = $mean;
	if ($standardMean eq "NaN") {
		return "NaN";
	}

	my $stddev = calc_stddev(@samples);
	my $conf = calc_confidence_interval_lower("NaN", $confidenceLevel, @samples);
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

			$mean = calc_mean(@samples);
			$stddev = calc_stddev(@samples);
			$conf = calc_confidence_interval_lower("NaN", $confidenceLevel, @samples);
			$limit = $mean * $confidenceLimit / 100;
			$conf_delta = $mean - $conf;

			printVerbose("  o recalc mean   = $mean\n");
			printVerbose("  o recalc stddev = $stddev\n");
			printVerbose("  o recalc con $confidenceLevel = $conf\n");
			printVerbose("  o limit     = $limit\n");
			printVerbose("  o con delta = $conf_delta\n");
		}
	}

	return calc_mean(@samples);
}

sub calc_stddev {
	my $n = 0;
	my $elements = $#_ + 1;
	my $diff;
	my $i;

	my $mean = calc_mean(@_);

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			if ($_[$i] !~ /^[-0-9]+/) {
				return "NaN";
			}
			$diff += ($_[$i] - $mean) ** 2;
			$n++;
		}
	}

	if ($n <= 1) {
		return "NaN";
	}

	return sqrt($diff / ($n - 1));
}

sub calc_coeffvar {
	my $stddev = calc_stddev(@_);
	my $mean = calc_mean(@_);

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
	my @x = sort { $a <=> $b} @_;
	my @quartiles;

	$quartiles[0] = 0;
	$quartiles[1] = $x[int($#x * 0.25 + 0.5)];
	$quartiles[2] = $x[int($#x * 0.50 + 0.5)];
	$quartiles[3] = $x[int($#x * 0.75 + 0.5)];
	$quartiles[4] = $x[$#x];
	$quartiles[90] = $x[int($#x * 0.90 + 0.5)];
	$quartiles[93] = $x[int($#x * 0.93 + 0.5)];
	$quartiles[95] = $x[int($#x * 0.95 + 0.5)];
	$quartiles[99] = $x[int($#x * 0.99 + 0.5)];

	chomp($quartiles[1]);
	chomp($quartiles[2]);
	chomp($quartiles[3]);
	chomp($quartiles[4]);
	chomp($quartiles[90]);
	chomp($quartiles[93]);
	chomp($quartiles[95]);
	chomp($quartiles[99]);

	return \@quartiles;
}

sub calc_confidence_interval {
	my $variance = shift;
	my $confidence_level = shift;
	my $elements = $#_ + 1;
	my $n = 0;
	my $i;
	my $stddev;
	my $q; my $q1;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			$n++;
		}
	}

	my $mean = calc_mean(@_);
	if ($variance !~ /^[-0-9]+/) {
		$stddev = calc_stddev(@_);
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
	my $variance = shift;
	my $confidence_level = shift;
	my $mean = calc_mean(@_);
	return $mean - calc_confidence_interval($variance, $confidence_level, @_);
}

sub calc_confidence_interval_upper {
	my $variance = shift;
	my $confidence_level = shift;
	my $mean = calc_mean(@_);
	return $mean + calc_confidence_interval($variance, $confidence_level, @_);
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

1;
