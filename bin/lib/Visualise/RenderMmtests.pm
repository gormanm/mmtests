package Visualise::RenderMmtests;
use Visualise::Visualise;
use Visualise::Container;
use Visualise::Render;
our @ISA = qw(Visualise::Visualise Visualise::Render);
use strict;

my $nid;
my $mmtestsMonitor;

sub initialise() {
	my ($self) = @_;

	$self->{_ModuleName} = "RenderMmtests";
	$self->SUPER::initialise();
}

sub setCutoff {
	my ($self, $cutoff) = @_;

	my @elements = split(/-/, $cutoff);
	die("Invalid specification $cutoff") if $elements[0] ne "node";
	$nid = $elements[1];;
}

sub setOutput {
	my ($self, $monitor) = @_;

	$mmtestsMonitor = $monitor;
}

my $nodeContainer;

sub getNodeContainer {
	my ($topologyModel) = @_;

	return $topologyModel->getModel()->getContainer("node-$nid");
}

sub renderOne {
	my ($self, $topologyModel, $timestamp) = @_;

	if (!defined($nodeContainer)) {
		$nodeContainer = getNodeContainer($topologyModel);
	}

	$mmtestsMonitor->addData("node-$nid", $timestamp, $nodeContainer->{_HValue});
}

1;
