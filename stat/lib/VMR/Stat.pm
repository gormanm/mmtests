#
# Stat.pm
#
# Basic stats module

package VMR::Stat;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&calc_mean &calc_stddev &calc_quartiles &calc_confidence_interval_lower &calc_confidence_interval_upper);

# Values taken from a standard normal table
my %za = (
	95=>1.96,
	99=>2.58,
);

sub calc_mean {
	my $sum = 0;
	my $n = 0;
	my $elements = $#_ + 1;
	my $i;

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			if ($_[$i] !~ /^[0-9]+/) {
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

sub calc_stddev {
	my $n = 0;
	my $elements = $#_ + 1;
	my $diff;
	my $i;

	my $mean = calc_mean(@_);

	for ($i = 0; $i < $elements; $i++) {
		if (defined $_[$i]) {
			if ($_[$i] !~ /^[0-9]+/) {
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

sub calc_quartiles {
	my @x = sort { $a <=> $b} @_;
	my @quartiles;

	$quartiles[0] = 0;
	$quartiles[1] = $x[int($#x * 0.25 + 0.5)];
	$quartiles[2] = $x[int($#x * 0.50 + 0.5)];
	$quartiles[3] = $x[int($#x * 0.75 + 0.5)];
	$quartiles[4] = $x[$#x];

	chomp($quartiles[1]);
	chomp($quartiles[2]);
	chomp($quartiles[3]);
	chomp($quartiles[4]);

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
