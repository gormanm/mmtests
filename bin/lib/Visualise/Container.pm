package Visualise::Container;
use strict;

my %all_containers;
my %title_map;

sub new() {
	my $class = shift;
	my $self = {};
	$self->{_ModuleName} = "Container";
	$self->{_SubContainers} = ();
	$self->{_Name} = "root";
	$self->{_Title} = "root";
	$self->{_Level} = 0;
	bless $self, $class;
	return $self;
}

sub setRoot() {
	my $self = shift;
	%all_containers = {};
	$all_containers{"root"} = $self;
}

sub add() {
	my ($self, $parent, $child, $title, $value) = @_;

	die("No parent node $parent\n") if !defined $all_containers{$parent};
	if (!defined $all_containers{$child}) {
		my $container = Visualise::Container->new();
		$container->{_Name} = $child;
		$container->{_Title} = $title;
		$all_containers{$child} = $container;
		push @{$all_containers{$parent}->{_SubContainers}}, $container;
	}
}

sub setLookup() {
	my ($self, $name, $key) = @_;

	$title_map{$name} = $key;
}

sub setContainerTitle() {
	my ($self, $name) = @_;

	$self->{_ContainerTitle} = $name;
}

sub getContainerTitle() {
	my ($self) = @_;

	return $self->{_ContainerTitle};
}

sub setValue() {
	my ($self, $key, $value) = @_;

	my $container = $all_containers{$key};
	if (!defined($container)) {
		$key = $title_map{$key};
		die if !defined($key);
		$container = $all_containers{$key};
		die if !defined($container);
	}
	$container->{_Value} = $value;
}

sub dump() {
	my ($self, $level, $name) = @_;

	my $container = %all_containers{$name};
	if ($level == 0) {
		print "$container->{_Title}\n";
	} else {
		printf("%${level}s %s\n", " ", $container->{_Title});
	}

	if (!defined $container->{_SubContainers}) {
		return;
	}
	foreach my $subcontainer (@{$container->{_SubContainers}}) {
		$self->dump($level + 1, $subcontainer->{_Name});
	}
}

sub dumpLookup() {
	foreach my $title (sort keys %title_map) {
		my $key = $title_map{$title};
		my $container = %all_containers{$key};
		print "$title -> $container->{_Name}\n";
	}
}

1;
