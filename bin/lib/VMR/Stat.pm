#
# Stat.pm
#
# Basic stats module

package VMR::Stat;
require Exporter;
use vars qw (@ISA @EXPORT);
use VMR::Report;
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&pdiff &pndiff &rdiff &sdiff &calc_sum &calc_min &calc_max &calc_range &calc_true_mean &calc_lowest_mean &calc_highest_mean &calc_highest_harmmean &calc_mean &calc_trimmed_mean &calc_geomean &calc_harmmean &calc_median &calc_coeffvar &calc_stddev &calc_quartiles &calc_confidence_interval_lower &calc_confidence_interval_upper);

# Values taken from a standard normal table
my %za = (
	95=>1.96,
	99=>2.58,
);

# created with R using "qt(c(0.975), df=$key); from df=22 added
# only smallest entries that differed at most 0.01 from previous entry
my %qt_975 = (
	1=>12.7062, 2=>4.302653, 3=>3.182446, 4=>2.776445, 5=>2.570582,
	6=>2.446912, 7=>2.364624, 8=>2.306004, 9=>2.262157, 10=>2.228139,
	11=>2.200985, 12=>2.178813, 13=>2.160369, 14=>2.144787, 15=>2.13145,
	16=>2.119905, 17=>2.109816, 18=>2.100922, 19=>2.093024, 20=>2.085963,
	21=>2.079614, 22=>2.073873, 24=>2.063899, 26=>2.055529, 28=>2.048407,
	31=>2.039513, 35=>2.030108, 40=>2.021075, 47=>2.011741, 57=>2.002465,
	74=>1.992543, 106=>1.982597, 188=>1.972663, 879=>1.962666,
	#inf=>1.959964
);

# created with R using "qt(c(0.995), df=$key); from df=33 added
# only smallest entries that differed at most 0.01 from previous entry
my %qt_995 = (
	1=>63.65674, 2=>9.924843, 3=>5.840909, 4=>4.604095, 5=>4.032143,
	6=>3.707428, 7=>3.499483, 8=>3.355387, 9=>3.249836, 10=>3.169273,
	11=>3.105807, 12=>3.05454, 13=>3.012276, 14=>2.976843, 15=>2.946713,
	16=>2.920782, 17=>2.898231, 18=>2.87844, 19=>2.860935, 20=>2.84534,
	21=>2.83136, 22=>2.818756, 23=>2.807336, 24=>2.79694, 25=>2.787436,
	26=>2.778715, 27=>2.770683, 28=>2.763262, 29=>2.756386, 30=>2.749996,
	31=>2.744042, 32=>2.738481, 33=>2.733277, 35=>2.723806, 37=>2.715409,
	39=>2.707913, 42=>2.698066, 45=>2.689585, 49=>2.679952, 54=>2.669985,
	60=>2.660283, 67=>2.65122, 76=>2.642078, 89=>2.632204, 107=>2.62256,
	135=>2.612738, 184=>2.602813, 291=>2.592829, 704=>2.582831,
	#inf=>2.575829
);

# quantile of t-distribution with
# $_[0] degrees of freedom and $_[1] confidence level
sub qt {
	my %qtt;
	my $q;

	if ( $_[1] == 99 ) {
		%qtt = %qt_995;
	} elsif ( $_[1] == 95 ) {
		%qtt = %qt_975;
	} else {
		return "NaN";
	}

	foreach my $key (reverse sort {$qtt{$b} <=> $qtt{$a}} keys %qtt) {
		if ( $_[0] >= $key ) {
			$q = $qtt{$key};
			last;
		}
	}
	return $q;
}

# Print the percentage difference between two values
sub pdiff {
	if ($_[0] == $_[1] || $_[0] == 0) {
		return 0;
	} elsif ($_[1] == 0) {
		return 100;
	} else {
		return $_[0] * 100 / $_[1] - 100;
	}
}

sub pndiff {
	if ($_[0] == $_[1]) {
		return 0;
	} elsif ($_[0] == 0) {
		return 100;
	} elsif ($_[1] == 0 && $_[0] != 0) {
		return -99;
	} else {
		return 100 - ($_[0] * 100 / $_[1]);
	}
}

sub rdiff {
	if ($_[1] == 0) {
		return 0;
	} else {
		return $_[0] / $_[1];
	}
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

sub calc_trimmed_mean {
	my $percentage = shift;
	$percentage /= 2;
	my $nr_elements = @_;
	my $nr_trim = int ($nr_elements * $percentage / 100);

	if ($nr_trim == 0 || $nr_trim * 2 > $nr_elements) {
		return calc_mean(@_);
	}

	my @sorted = sort { $a <=> $b } @_;
	my @trimmed = @sorted[$nr_trim..$nr_elements - $nr_trim];

	return calc_mean(@trimmed);
}


sub calc_highest_mean {
	my $percentage = shift;
	my $nr_elements = @_;
	my $nr_trim = int ($nr_elements * $percentage / 100);

	if ($nr_trim == 0) {
		return calc_mean(@_);
	}

	my @sorted = sort { $a <=> $b } @_;
	my @trimmed = @sorted[$nr_trim..$nr_elements];

	return calc_mean(@trimmed);
}

sub calc_highest_harmmean {
	my $percentage = shift;
	my $nr_elements = @_;
	my $nr_trim = int ($nr_elements * $percentage / 100);

	if ($nr_trim == 0) {
		return calc_harmmean(@_);
	}

	my @sorted = sort { $a <=> $b } @_;
	my @trimmed = @sorted[$nr_trim..$nr_elements];

	return calc_harmmean(@trimmed);
}

sub calc_lowest_mean {
	my $percentage = shift;
	my $nr_elements = @_;
	my $nr_trim = int ($nr_elements * $percentage / 100);

	if ($nr_trim == 0) {
		return calc_mean(@_);
	}

	my @sorted = sort { $a <=> $b } @_;
	my @trimmed = @sorted[0..$nr_trim];

	return calc_mean(@trimmed);
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
	my $q;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			$n++;
		}
	}

	my $mean = calc_mean(@_);
	if ($variance !~ /^[-0-9]+/) {
		$stddev = calc_stddev(@_);
		$q = qt($n-1, $confidence_level);
	} else {
		$stddev = sqrt($variance);
		$q = $za{$confidence_level};
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

1;
