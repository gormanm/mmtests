package Visualise::ModelTopology;
use Visualise::Visualise;
use Visualise::Container;
our @ISA = qw(Visualise::Visualise);
use strict;

sub initialise() {
	my ($self) = @_;

	$self->{_ModuleName} = "ModelTopology";
	$self->SUPER::initialise();
}

my %levels = {
	"node"		=> 1,
	"socket"	=> 2,
	"llc"		=> 3,
	"core"		=> 4,
	"cpu"		=> 5,
};

my $container;

sub parse() {
	my ($self, $file) = @_;

	my $input = $self->SUPER::open_file($file);
	die("Unable to open $file") if !defined $input;

	$container = Visualise::Container->new();
	$container->setRoot();

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

	return $container;
}

sub getModel() {
	my ($self) = @_;
	return $container;
}

1;
