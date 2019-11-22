package Visualise::ModelTopology;
use Visualise::Visualise;
use Visualise::Container;
use Visualise::Model;
our @ISA = qw(Visualise::Visualise Visualise::Model);
use strict;

my @levels = ( "machine", "node", "socket", "llc", "core", "cpu" );
my $cutoffLevel;
my $cutoffLevelName;

sub initialise {
	my ($self) = @_;

	$self->{_ModuleName} = "ModelTopology";
	$self->SUPER::initialise();
}

sub getCutoff {
	return $cutoffLevel;
}

sub getCutoffLevelName {
	return $cutoffLevelName;
}

sub setCutoff {
	my ($self, $cutoff) = @_;

	for (my $i = 0; $i <= $#levels; $i++) {
		if ($levels[$i] eq $cutoff) {
			$cutoffLevel = $i;
			$cutoffLevelName = $cutoff;
			return;
		}
	}
	die("Unrecognised cutoff $cutoff");
}

sub mapLevel {
	my ($container) = @_;

	$container->{_LevelName} = @levels[$container->{_Level}];
}

sub setLevelNames {
	my ($self) = @_;

	my $container = $self->getModel();
	$container->walkTree(\&mapLevel);
}

sub getLeafNodes {
	my ($self) = @_;

	$self->getModel()->getLeafNodes($cutoffLevelName);
}

sub parse {
	my ($self, $file) = @_;

	my $input = $self->SUPER::open_file($file);
	die("Unable to open $file") if !defined $input;

	my $container = Visualise::Container->new();
	$container->setRoot();
	$self->setModel($container);

	while (!eof($input)) {
		my $line = <$input>;

		my @elements = split(/\s/, $line);
		my $node	= $elements[1];
		my $socket	= $elements[3];
		my $core	= $elements[5];
		my $thread	= $elements[7];
		my $cpu		= $elements[9];
		my $llc		= defined $elements[11] ? $elements[11] : $node;

		$container->add("root", "node-$node", "node $node", $node);
		$container->add("node-$node", "node-$node-socket-$socket", "socket $socket", $socket);
		$container->add("node-$node-socket-$socket", "node-$node-socket-$socket-llc-$llc", "llc $llc", $llc);
		$container->add("node-$node-socket-$socket-llc-$llc", "node-$node-socket-$socket-llc-$llc-core-$core", "core $core", $core);
		$container->add("node-$node-socket-$socket-llc-$llc-core-$core", "node-$node-socket-$socket-llc-$llc-core-$core-cpu-$cpu", "cpu $cpu", $cpu);
		$container->setLookup("cpu $cpu", "node-$node-socket-$socket-llc-$llc-core-$core-cpu-$cpu");
	}
	close($input);
	$self->setLevelNames();
	$container->trimMiddle();

	# Cutoff might be on non-existent level
	if (defined($cutoffLevelName)) {
		while ($cutoffLevel > 1 && !$container->levelExists($cutoffLevelName)) {
			$cutoffLevelName = $levels[$cutoffLevel];
		}
		$cutoffLevel = $container->getLevelIndex($cutoffLevelName);
		die("Tree became completely inconsistent") if ($cutoffLevel <= 0);
	}

	return $container;
}

1;
