#!/usr/bin/perl
# visualise-log.pl - Visualise some log files
#
# Certain logs are very difficult to analyse by hand. This tool can visualise
# some data but note that the support is very limited.
#
# Copyright: SUSE Labs, 2019
# Author:    Mel Gorman, 2019

use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use Pod::Usage;
use MMTests::Report;
use Visualise::VisualiseFactory;
use strict;

# Option variable
my ($opt_verbose);
my ($opt_help, $opt_manual);
my ($opt_input, $opt_output);
my ($opt_format, $opt_render);
my ($opt_topology, $opt_type);
my $opt_render_backend = "dot";
my $opt_input_format = "mpstat";
my $opt_format = "png";
my $opt_activity;
GetOptions(
	'verbose|v'		=> \$opt_verbose,
	'help|h'		=> \$opt_help,
	'manual'		=> \$opt_manual,
	'a|activity=s'		=> \$opt_activity,
	'i|input=s'		=> \$opt_input,
	'o|output=s'		=> \$opt_output,
	'f|output-format=s'	=> \$opt_format,
	'l|log-format=s'	=> \$opt_type,
	'r|render=s'		=> \$opt_render,
	'b|render-backend=s'	=> \$opt_render_backend,
	't|topology=s'		=> \$opt_topology,
	
);
setVerbose if $opt_verbose;
pod2usage(-exitstatus => 0, -verbose => 0) if $opt_help;
pod2usage(-exitstatus => 0, -verbose => 2) if $opt_manual;

# Sanity check directory
if (!defined $opt_output || -e $opt_output) {
	printWarning("Output $opt_output already exists.");
	pod2usage(-exitstatus => -1, -verbose => 0);
}

if (!defined $opt_input) {
	$opt_type = "none";
}

my $model;
my $renderer;
my $logparser;

# Parse topology if specified
if (defined $opt_topology) {
	my $modelFactory = Visualise::VisualiseFactory->new();
	$model = $modelFactory->loadModule("model", "topology");
	$model->parse($opt_topology);

	my $renderFactory = Visualise::VisualiseFactory->new();
	$renderer = $renderFactory->loadModule("render", "topology$opt_render_backend");
	$renderer->setOutput($opt_output);
	$renderer->setFormat($opt_format);
}

# Parse logs if specified
my $logparserFactory = Visualise::VisualiseFactory->new();
$logparser = $logparserFactory->loadModule("extract", $opt_type);
$logparser->addActivity($opt_activity);
$logparser->start($opt_input);
while ($logparser->parseOne($model)) {
	$renderer->renderOne($model);	
	#$model->dump($model->getModel(), "_Value");
	#$model->dump($model->getModel(), "_HValue");
	$model->clearValues();
}
$logparser->end($opt_input);

if (defined $renderer && $renderer->getNrFrames() > 1) {
	my $framerate = int(10 / $logparser->getFrequency());
	if ($framerate == 0) {
		$framerate = 1;
	}
	
	print("VIDEO: ffmpeg -loglevel fatal -framerate " . $framerate . " -i " . $renderer->getFramePattern() . " -c:v libx264 " . $renderer->getVideoDirectory() . "/video.mp4\n");
	system("ffmpeg -loglevel fatal -framerate " . $framerate . " -i " . $renderer->getFramePattern() . " -c:v libx264 " . $renderer->getVideoDirectory() . "/video.mp4\n");
}

# Below this line is help and manual page information
__END__
=head1 NAME

visualise-log.pl - Visualise a log

=head1 SYNOPSIS

=cut
