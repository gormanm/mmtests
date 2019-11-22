package Visualise::RenderTopologydot;
use Visualise::Visualise;
use Visualise::Container;
use Visualise::Render;
use Math::Gradient qw(multi_array_gradient);
our @ISA = qw(Visualise::Render Visualise::Visualise);
use strict;

my %title_map;
my $cluster_id = 0;
my $outputFormat;
my @gradient;
my $cutoffLevel = 9999;

sub initialise() {
	my ($self) = @_;
	$self->{_ModuleName} = "RenderTopologydot";
	$self->SUPER::initialise();

	my @spots = ([ 255, 255, 255 ], [ 0, 255, 0 ], [ 255, 255, 0 ], [ 255, 165, 0 ], [ 255, 0, 0 ], [100, 50, 50 ] );
	@gradient = multi_array_gradient(101, @spots);
}

sub setCutoff() {
	my ($self, $cutoff) = @_;

	$cutoffLevel = $cutoff;
}

sub setOutput() {
	my ($self, $directory) = @_;

	$self->setOutputDirectory($directory);
}

sub loadToColour() {
	my ($self, $container, $load) = @_;
	my $nrLeafNodes = $container->{_NrLeafNodes};

	# Scale load relative to the topology
	if ($nrLeafNodes) {
		$load /= $nrLeafNodes;
	}
	my $color = sprintf("#%02X%02X%02X", int($gradient[int $load][0]), int($gradient[int $load][1]), int($gradient[int $load][2]));
	return $color;
}

sub generateLabel {
	my ($container, $level) = @_;
	my $shortkey = $container->{_ShortKey};
	my $node = "";
	my $activeCpus = "";

	# Prepend node ID if not the CPU level to generate a unique ID
	# Append information on the number of active and total cpus
	if ($level != 5) {
		if ($level != 1) {
			my $nodeContainer = $container;
			while ($level != 1) {
				$nodeContainer = $nodeContainer->{_Parent};
				$level--;
			}
			my ($dummy, $nodeID) = split(/ /, $nodeContainer->{_ShortKey});
			$node = "$nodeID-";
		}

		$activeCpus = "\n$container->{_NrActiveLeafNodes}/$container->{_NrLeafNodes} cpus";
	}

	my @elements = split(/ /, $shortkey);
	return sprintf("$node$elements[0] %03d\\n%4.2f%%$activeCpus", $elements[1], $container->{_HValue});
}

my $clusterID = 0;
my %renderSublevel;
my $multiLLC = 0;
my @firstCores;
my $splitLLC = 4;
my $splitCores = 4;

sub renderLevel {
	my ($self, $level, $renderSubgraph, $container, $layoutNodesRef, $layoutNodePrefix) = @_;
	my $indent = sprintf("%" . ($level * 2) . "s", " ");
	my $dot;
	my $place;
	my $testLevel = $container->{_Level};
	my $levelName = $container->{_LevelName};
	die if ($testLevel != $level);

	# Final level
	if (ref($container->{_SubContainers}) ne "ARRAY" || $level >= $cutoffLevel) {
		my $label = generateLabel($container, $level);

		my $colour = "#ffffff";
		my $load = $container->{_HValue};
		if ($load ne "" && $load != 0) {
			$colour = $self->loadToColour($container, $load);
		}

		return "${indent}\"$label\" [ shape=square,style=filled,fillcolor=\"$colour\" ];\n";
	}

	if ($renderSubgraph) {
		$dot .= "${indent}subgraph cluster_$clusterID  {\n";
		$dot .= "${indent}  label = \"$container->{_ShortKey}$place\"\n";
		$dot .= "\n";
	}

	$renderSublevel{$level} = 1;
	if (scalar(@{$container->{_SubContainers}}) == 1) {
		$renderSublevel{$level} = 0;
	}
	if ($levelName eq "socket" && $renderSublevel{$level}) {
		$multiLLC = 1;
	}
	my $containerIndex = 0;
	my @layoutNodes;

	# Record first CPU of every core within an llc
	if ($levelName eq "llc") {
		@firstCores = ();
	}
	if ($levelName eq "core") {
		my $firstContainer = @{$container->{_SubContainers}}[0];
		my $firstLabel = generateLabel($firstContainer, $level + 1);
		push @firstCores, $firstLabel;
	}

	foreach my $subContainer (reverse(@{$container->{_SubContainers}})) {
		$clusterID++;
		$containerIndex++;
		$dot .= renderLevel($self, $level + 1, $renderSublevel{$level}, $subContainer, \@layoutNodes, "${layoutNodePrefix}_");

		# Special case layout of LLC when there are multiple ones per socket
		if ($levelName eq "llc" && $multiLLC) {
			if ($containerIndex % $level == 0) {
				push @{$layoutNodesRef}, "lNode$layoutNodePrefix${containerIndex}_$clusterID";
				$dot .= "${indent} lNode$layoutNodePrefix${containerIndex}_$clusterID [ label = \"\", style=invis, shape=point]\n";
			}
		}
	}

	if ($multiLLC) {
		for (my $i = 0; $i < scalar(@layoutNodes) - 1; $i++) {
			if ((scalar(@layoutNodes) - $i < $splitLLC) || (($i + 1) % 5 != 0)) {
				$dot .= "${indent}$layoutNodes[$i] -> $layoutNodes[$i+1] [ style=invis ]\n";
			}
		}
	}
	if ($renderSubgraph) {
		$dot .= "${indent}}\n";
	}

	return $dot;
}

sub renderOne() {
	my ($self, $model) = @_;
	my $container = $model->getModel();

	my $dot = "digraph {\n";
	$dot .= "  graph [ compound=true ]\n";
	
	$dot .= "  label = \"" . $container->getContainerTitle() . "\"\n";

	foreach my $nodeContainer (@{$container->{_SubContainers}}) {
		$dot .= $self->renderLevel(1, 1, $nodeContainer);
		if (scalar(@firstCores) > $splitCores * 2) {
			for (my $i = scalar(@firstCores) - 1; $i > 0; $i--) {
				if ($i % $splitCores != 0) {
					$dot .= "  \"@firstCores[$i]\" -> \"@firstCores[$i-1]\" [ style=invis]\n";
				}
			}
		}
	}

	$dot .= "}\n";

	my $frame = $self->getNrFrames();
	open (my $output, ">$self->{_OutputDirectory}/scratch/frame-$frame.dot") || die("Failed to open output dot file");
	print $output $dot;
	close($output);

	system("dot -T$self->{_OutputFormat} $self->{_OutputDirectory}/scratch/frame-$frame.dot -o $self->{_OutputDirectory}/frames/frame-$frame.$self->{_OutputFormat}");
	$self->SUPER::renderOne();
}

1;
