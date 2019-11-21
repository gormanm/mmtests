package Visualise::Render;
use Visualise::Visualise;
use Visualise::Container;
our @ISA = qw(Visualise::Visualise);
use strict;

sub initialise() {
	my ($self) = @_;

	$self->{_Frames} = 0;
}

sub renderOne() {
	my ($self) = @_;

	$self->{_Frames}++;
}

sub setFormat() {
	my ($self, $format) = @_;

	$self->{_OutputFormat} = $format;
}

sub getFramePattern() {
	my ($self) = @_;

	if ($self->{_OutputDirectory}) {
		return "$self->{_OutputDirectory}/frames/frame-%d.$self->{_OutputFormat}";
	}
}

sub getNrFrames() {
	my ($self) = @_;

	return $self->{_Frames};
}

sub getVideoDirectory() {
	my ($self) = @_;

	return "$self->{_OutputDirectory}/video";
}

sub setOutputDirectory() {
	my ($self, $directory) = @_;
	
	$self->{_OutputDirectory} = $directory;
	mkdir($directory) || die("Failed to create output directory $directory");
	mkdir("$directory/frames") || die("Failed to create frames directory $directory/frames");
	mkdir("$directory/video") || die("Failed to create video directory $directory/video");
	mkdir("$directory/scratch") || die("Failed to create scratch directory $directory/scratch");
}

sub start {
}

1;
