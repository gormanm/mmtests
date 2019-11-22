package Visualise::RenderTopologygd;
use Visualise::Visualise;
use Visualise::Container;
use Visualise::Render;
use GD::Image;
use Math::Gradient qw(multi_array_gradient);
our @ISA = qw(Visualise::Render Visualise::Visualise);
use strict;

my $outputFormat;
my @gradient;
my $black;
my $font;
my $cutoffLevel = 9999;
my $canvas;
my $cWidth = 1024;
my $marginCWidth = 100;
my $leafCWidth = 1014;
my $leafCHeight = 30;
my $levelCWidth = 8;
my $sampleCWidth = 1;

my $topologyModel;
my @leafNodes;
my @samples;

sub initialise() {
	my ($self) = @_;
	$self->{_ModuleName} = "RenderTopologydot";
	$self->SUPER::initialise();
}

sub setCutoff() {
	my ($self, $cutoff) = @_;

	if ($cutoff > 5) {
		$cutoff = 5;
	}

	if ($cutoff < 1) {
		$cutoff = 1;
	}

	$cutoffLevel = $cutoff;
}

sub setOutput() {
	my ($self, $file) = @_;

	$self->setOutputFile($file);
}

sub loadToColour() {
	my ($self, $container, $load) = @_;
	my $nrLeafNodes = scalar(@leafNodes);

	# Scale load relative to the topology
	if ($nrLeafNodes) {
		$load /= $nrLeafNodes;
	}
	my $color = sprintf("#%02X%02X%02X", int($gradient[int $load][0]), int($gradient[int $load][1]), int($gradient[int $load][2]));
	return $color;
}

sub cpuLX {
	my ($cpu) = @_;

	return $marginCWidth;
}

sub cpuTY {
	my ($cpu) = @_;
	return $cpu * $leafCHeight;
}

sub cpuRX {
	my ($cpu) = @_;
	return cpuLX($cpu) + $leafCWidth;
}

sub cpuBY {
	my ($cpu) = @_;
	return cpuTY($cpu) + $leafCHeight;
}

sub start {
	my ($self, $model) = @_;

	$topologyModel = $model;
	@leafNodes = $model->getModel()->getLeafNodes($cutoffLevel);
}

sub getNrFrames {
	return 1;
}

sub renderOne() {
	my ($self, $model) = @_;
	my $container = $model->getModel();

	for (my $i = 0; $i < scalar(@leafNodes); $i++) {
		push @{$samples[$i]}, $leafNodes[$i]->{_HValue};
	}

	$self->SUPER::renderOne();
}

sub sampleLX {
	my ($cpu, $sample) = @_;

	return cpuLX($cpu) + $sample * $sampleCWidth;
}
sub sampleTY {
	my ($cpu, $sample) = @_;

	return cpuTY($cpu) + 1;
}

sub sampleRX {
	my ($cpu, $sample) = @_;

	return sampleLX($cpu, $sample) + $sampleCWidth - 1;
}

sub sampleBY {
	my ($cpu, $sample) = @_;

	return cpuBY($cpu) - 1;
}

sub levelX {
	my ($cpu, $level) = @_;

	return $levelCWidth * $level + 1;
}

sub renderStart {
	my ($cpu, $level) = @_;

	my $x = levelX($cpu, $level);
	my $y = cpuTY($cpu) + $leafCHeight / 2;

	$canvas->line($x, $y, $x,		     cpuBY($cpu), $black);
	$canvas->line($x, $y, $x + $levelCWidth - 3, $y,          $black);
}

sub renderEnd {
	my ($cpu, $level) = @_;

	my $x = levelX($cpu, $level);
	my $y = cpuBY($cpu) - $leafCHeight / 2;

	$canvas->line($x, cpuTY($cpu), $x,                    $y, $black);
	$canvas->line($x, $y,          $x + $levelCWidth - 3, $y, $black);
}

sub renderSame {
	my ($cpu, $level) = @_;
	my $x = levelX($cpu, $level);

	$canvas->line($x, cpuTY($cpu), $x, cpuBY($cpu), $black);
}

sub parentAtLevel {
	my ($container, $level) = @_;

	while ($container->{_Level} != $level) {
		$container = $container->{_Parent};
	}

	return $container;
}

sub renderLevels {
	my ($cpu) = @_;
	my $container = $leafNodes[$cpu];
	my $top = $container;

	if ($top->{_Level} == 1) {
		return;
	}

	while ($top->{_Level} != 1) {
		$top = $top->{_Parent};
	}

	my $level = $container->{_Level};
	do {
		if ($cpu == 0) {
			renderStart($cpu, $level);
		} elsif ($cpu == $#leafNodes) {
			renderEnd($cpu, $level);
		} else {
			my $nextContainer = $leafNodes[$cpu+1];
			my $thisParent = parentAtLevel($container, $level - 1);
			my $lastParent = parentAtLevel($leafNodes[$cpu-1], $level - 1);
			my $nextParent = parentAtLevel($leafNodes[$cpu+1], $level - 1);

			if ($thisParent->{_Key} ne $nextParent->{_Key}) {
				renderEnd($cpu, $level);
			} elsif ($thisParent->{_Key} ne $lastParent->{_Key}) {
				renderStart($cpu, $level);
			} else {
				renderSame($cpu, $level);
			}
		}

		$container = $container->{_Parent};
		$level--;
	} while ($container != $top);
}

sub end() {
	my ($self) = @_;
	my $i;

	# Size width of canvas to fit excessive samples if necessary
	my $nr_samples = scalar(@{$samples[0]});
	if ($cWidth < $nr_samples) {
		$leafCWidth += $nr_samples - $cWidth;
		$cWidth = $nr_samples;
	}

	# Size width of a sample based on the canvas
	$sampleCWidth = int($cWidth / $nr_samples);
	if ($sampleCWidth == 0) {
		$sampleCWidth = 1;
	}

	# Render the canvas
	my $cHeight = $leafCHeight * scalar(@leafNodes);
	my $nr_colors = 100;
	my @spots = ([ 255, 255, 255 ], [ 0, 255, 0 ], [ 255, 255, 0 ], [ 255, 165, 0 ], [ 255, 0, 0 ], [100, 50, 50 ] );
	@gradient = multi_array_gradient($nr_colors + 1, @spots);
	$canvas = new GD::Image($cWidth, $cHeight);
	for ($i = 0; $i <= $nr_colors; $i++) {
		$gradient[$i] = $canvas->colorAllocate($gradient[$i][0], $gradient[$i][1], $gradient[$i][2]);
	}
	$black = $canvas->colorAllocate(0, 0, 0);

	# Render lines and text for each CPU band
	for ($i = 0; $i < scalar(@leafNodes); $i++) {
		$canvas->line(cpuLX($i), cpuTY($i), cpuRX($i), cpuTY($i), $black);
		$canvas->string(GD::gdSmallFont, cpuLX($i) - 45, cpuTY($i) + 10, $leafNodes[$i]->{_ShortKey}, $black);
		renderLevels($i);
	}
	$canvas->line(cpuLX(0), 0, cpuLX(0), $cHeight, $black);

	# Render CPU samples
	for ($i = 0; $i < scalar(@leafNodes); $i++) {
		my @cpuUtil = @{$samples[$i]};
		for (my $sample = 0; $sample < scalar(@cpuUtil); $sample++) {
			if ($sampleCWidth > 1) {
				$canvas->filledRectangle(sampleLX($i, $sample), sampleTY($i, $sample),
					        sampleRX($i, $sample), sampleBY($i, $sample),
						$gradient[int($cpuUtil[$sample])]);
			} else {
				$canvas->line(sampleLX($i, $sample), sampleTY($i, $sample),
					        sampleRX($i, $sample), sampleBY($i, $sample),
						$gradient[int($cpuUtil[$sample])]);
			}
		}
	}

	open(my $output, ">$self->{_OutputFile}") || die("Failed to open output file\n");
	binmode $output;
	my $format = $self->getFormat();
	print $output $canvas->$format;
}

1;
