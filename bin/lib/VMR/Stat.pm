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
@EXPORT = qw(&pdiff &pndiff &rdiff &sdiff &calc_sum &calc_min &calc_max &calc_range &calc_true_mean &calc_lowest_mean &calc_mean &calc_geomean &calc_harmmean &calc_median &calc_coeffvar &calc_stddev &calc_quartiles &calc_confidence_interval_lower &calc_confidence_interval_upper);

# Values taken from a standard normal table
my %za = (
	95=>1.96,
	99=>2.58,
);

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
	my ($new, $base, $stddev) = @_;
	my $diff = $new - $base;
	if ($stddev == 0) {
		return $diff;
		# Typically, this occurs for little integers under 20
		# and here we want to see if anything changes so issuing
		# quite high numbers (directly the difference).
	} else {
		return $diff / $stddev;
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
	my $mid = int $nr_elements / 2;

	my @sorted = sort { $a <=> $b } @_;
	if ($nr_elements % 2 == 0) {
		return $sorted[$nr_elements / 2];
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
	my $conf = calc_confidence_interval_lower($confidenceLevel, @samples);
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
			$conf = calc_confidence_interval_lower($confidenceLevel, @samples);
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

	if ($n == 0) {
		return "NaN";
	}

	return sqrt($diff / $n);
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
	my $confidence_level = shift;
	my $elements = $#_ + 1;
	my $n = 0;
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			$n++;
		}
	}

	my $mean = calc_mean(@_);
	my $stddev = calc_stddev(@_);

	return ($za{$confidence_level}*($stddev/sqrt($n)));
}

sub calc_confidence_interval_lower {
	my $confidence_level = shift;
	my $mean = calc_mean(@_);
	return $mean - calc_confidence_interval($confidence_level, @_);
}

sub calc_confidence_interval_upper {
	my $confidence_level = shift;
	my $mean = calc_mean(@_);
	return $mean + calc_confidence_interval($confidence_level, @_);
}

1;
