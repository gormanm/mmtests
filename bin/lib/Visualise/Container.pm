package Visualise::Container;
use strict;

my %all_containers;
my %title_map;

sub new {
	my $class = shift;
	my $self = {};
	$self->{_ModuleName} = "Container";
	$self->{_SubContainers} = ();
	$self->{_Key} = "root";
	$self->{_ShortKey} = "root";
	$self->{_Level} = 0;
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
		$all_containers{$child} = $container;
		push @{$parentContainer->{_SubContainers}}, $container;
	}
}

sub setLookup {
	my ($self, $name, $key) = @_;

	$title_map{$name} = $key;
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

sub clearValues() {
	my ($self, $container) = @_;

	$container->{_Value} = undef;
	if (!defined $container->{_SubContainers}) {
		return;
	}

	foreach my $subContainer (@{$container->{_SubContainers}}) {
		$container->clearValues($subContainer);
	}
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
		printf("%${level}s %-${padding}s $field %${level}s%${valpadding}s\n", " ", $container->{_ShortKey}, " ", $container->{$field});
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
