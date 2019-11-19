package Visualise::ExtractNone;
use Visualise::Visualise;
use Visualise::Container;
our @ISA = qw(Visualise::Visualise);
use strict;

my $frames = 1;

sub new() {
	my $class = shift;
	my $self = {};
	$self->{_ModuleName} = "ExtractNone";

	bless $self, $class;
	return $self;
}

sub addActivity() {
}

sub initialise() {
}

sub parseOne() {
	return $frames--;
}

sub start() {
}

sub end() {
}

1;
