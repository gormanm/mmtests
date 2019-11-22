package Visualise::Container;
use strict;

my %all_containers;
my %title_map;
my @leaf_nodes = undef;

sub new {
	my $class = shift;
	my $self = {};
	$self->{_ModuleName} = "Container";
	$self->{_SubContainers} = ();
	$self->{_Key} = "root";
	$self->{_ShortKey} = "root";
	$self->{_Level} = 0;
	$self->{_LevelName} = "machine";
	bless $self, $class;
	return $self;
}

sub setRoot {
	my $self = shift;
	%all_containers = {};
	$all_containers{"root"} = $self;
}

sub add {
	my ($self, $parent, $child, $title, $value) = @_;

	die("No parent node $parent\n") if !defined $all_containers{$parent};
	if (!defined $all_containers{$child}) {
		my $parentContainer = $all_containers{$parent};
		my $container = Visualise::Container->new();
		$container->{_Key} = $child;
		$container->{_ShortKey} = $title;
		$container->{_Parent} = $parentContainer;
		$container->{_Level} = $parentContainer->{_Level} + 1;
		$all_containers{$child} = $container;
		push @{$parentContainer->{_SubContainers}}, $container;
		@leaf_nodes = ();
	}
}

sub setLookup {
	my ($self, $name, $key) = @_;

	$title_map{$name} = $key;
}

sub getLevelName {
	my ($self, $container) = @_;
	return $container->{_LevelName};
}

sub setLevelName {
	my ($self, $container, $levelName) = @_;

	$container->{_LevelName} = $levelName;
}

sub setContainerTitle {
	my ($self, $name) = @_;

	$self->{_ContainerTitle} = $name;
}

sub getContainerTitle {
	my ($self) = @_;

	return $self->{_ContainerTitle};
}

sub getContainer {
	my ($self, $key) = @_;

	my $container = $all_containers{$key};
	if (!defined($container)) {
		$key = $title_map{$key};
		die("Unable to identify unique key from '$key'") if !defined($key);
		$container = $all_containers{$key};
		die if !defined($container);
	}

	return $container;
}

sub getField {
	my ($self, $key, $field) = @_;

	my $container = $self->getContainer($key);
	return $container->{$field};
}

sub getValue {
	my ($self, $key) = @_;
	my $container = $self->getContainer($key);
	return $container->{_Value};
}

sub setValue {
	my ($self, $key, $value) = @_;

	my $container = $self->getContainer($key);
	$container->{_Value} = $value;
}

sub addLeafNode {
	my ($container, $maxdepth) = @_;

	if (defined($maxdepth)) {
		if ($container->{_LevelName} eq $maxdepth) {
			push @leaf_nodes, $container;
		}
		return;
	}

	if (defined($container->{_SubContainers})) {
		return;
	}

	push @leaf_nodes, $container;
}

sub walkTreeIter {
	my ($container, $callback, $parameter) = @_;

	&$callback($container, $parameter);
	if (!defined $container->{_SubContainers}) {
		return;
	}
	foreach my $subContainer (@{$container->{_SubContainers}}) {
		walkTreeIter($subContainer, $callback, $parameter);
	}
}

sub walkTree {
	my ($self, $callback, $parameter) = @_;

	walkTreeIter($all_containers{"root"}, $callback, $parameter);
}

sub getLeafNodes {
	my ($self, $maxdepth) = @_;

	if (scalar(@leaf_nodes) > 0) {
		return @leaf_nodes;
	}

	$self->walkTree(\&addLeafNode, $maxdepth);
	return @leaf_nodes;
}

# Calculates a hierarchical value for each node as the sum of values from
# all children
sub propogateValues {
	my ($self, $container) = @_;
	my $isLeaf = 0;
	my $isActiveLeaf = 0;

	if (!defined($container)) {
		$container = $all_containers{"root"};
	}

	$container->{_HValue} = $container->{_Value};
	$container->{_NrLeafNodes} = 0;
	$container->{_NrActiveLeafNodes} = 0;
	if (defined $container->{_SubContainers}) {
		foreach my $subContainer (@{$container->{_SubContainers}}) {
			$container->propogateValues($subContainer);
		}
	} else {
		$isLeaf = 1;
		if ($container->{_Value} > 0) {
			$isActiveLeaf = 1;
		}
	}

	my $parent = $container->{_Parent};
	if (defined($parent)) {
		$parent->{_HValue} += $container->{_HValue};
		$parent->{_NrLeafNodes} += $isLeaf + $container->{_NrLeafNodes};
		$parent->{_NrActiveLeafNodes} += $isActiveLeaf + $container->{_NrActiveLeafNodes};
	}
}

sub clearValues {
	my ($self, $container) = @_;

	$container->{_Value} = undef;
	if (!defined $container->{_SubContainers}) {
		return;
	}

	foreach my $subContainer (@{$container->{_SubContainers}}) {
		$container->clearValues($subContainer);
	}
}

sub levelExists {
	my ($self, $level) = @_;
	my $container = $self;

	do {
		if ($container->{_LevelName} eq $level) {
			return 1;
		}
		$container = $container->{_SubContainers}[0];
	} while (defined($container->{_SubContainers}));

	return 0;
}

sub getLevelIndex {
	my ($self, $levelName) = @_;
	my $container = $self;
	my $level = 0;

	do {
		if ($container->{_LevelName} eq $levelName) {
			return $level;
		}
		$container = $container->{_SubContainers}[0];
		$level++;
	} while (defined($container->{_SubContainers}));
	return -1;
}

sub dropLevel {
	my ($container) = @_;

	$container->{_Level}--;
}

sub reparent {
	my ($parent, $child) = @_;

	$parent->{_SubContainers} = ();
	foreach my $subContainer (@{$child->{_SubContainers}}) {
		$subContainer->{_Parent} = $parent;
		push @{$parent->{_SubContainers}}, $subContainer;
	}
}

sub trimMiddlePass {
	my ($container) = @_;
	my $nrRemoved = 0;
	if (!defined($container->{_SubContainers})) {
		return;
	}

	if (scalar(@{$container->{_SubContainers}}) == 1) {
		my @containersIter = @{$container->{_SubContainers}};
		foreach my $subContainer (@containersIter) {
			reparent($container, $subContainer);
			$nrRemoved++;
			walkTreeIter($subContainer, \&dropLevel);
		}
	}

	return $nrRemoved;
}

sub trimMiddle {
	my ($self) = @_;

	my $container = $all_containers{"root"};
	if (!defined($container->{_SubContainers})) {
		return;
	}

	my @containersIter = @{$container->{_SubContainers}};
	my $layerRemoved;
	do {
		$layerRemoved = 0;
		foreach my $subContainer (@containersIter) {
			$layerRemoved += trimMiddlePass($subContainer);
		}
	} while ($layerRemoved != 0);
}

sub dump {
	my ($self, $level, $container, $field) = @_;

	if ($field eq "") {
		$field = "_Value";
	}

	if ($level == 0) {
		print "$container->{_ShortKey}\n";
	} else {
		my $padding = 16 - $level;
		my $valpadding = 21 - $level;
		printf("(%d)%${level}s %-${padding}s $field %${level}s%${valpadding}s\n", $container->{_Level}, " ", $container->{_ShortKey}, " ", $container->{$field});
	}

	if (!defined $container->{_SubContainers}) {
		return;
	}
	foreach my $subcontainer (@{$container->{_SubContainers}}) {
		$self->dump($level + 1, $subcontainer, $field);
	}
}

sub dumpLookup {
	foreach my $title (sort keys %title_map) {
		my $key = $title_map{$title};
		my $container = $all_containers{$key};
		print "$title -> $container->{_Key}\n";
	}
}

1;
