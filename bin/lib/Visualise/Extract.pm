package Visualise::Extract;
use Visualise::Visualise;
use Visualise::Container;
our @ISA = qw(Visualise::Visualise);

use strict;

my $input;
my @timestamps;
my @activities;

sub initialise() {
	my ($self) = @_;

	$self->{_Frequency} = 0;
}

sub start() {
	my ($self, $file) = @_;

	$input = $self->SUPER::open_file($file) || die("Failed to open log file $file");
}

sub addActivity() {
	my ($self, $file) = @_;

	if (!defined($file) || $file eq "") {
		return;
	}

	my $fh = $self->SUPER::open_file($file) || return;
	my $i = 0;

	while (!eof($fh)) {
		my $line = <$fh>;

		next if ($line =~ /: iteration /);
		next if ($line =~ /: tserver-/);
		if ($line =~ /^([0-9]*) (.*)/) {
			$timestamps[$i] = $1;
			$activities[$i] = $2;
			$i++;
		}
	}
	close($fh);
}

sub getActivity() {
	my ($self, $timestamp) = @_;

	my $activity = "start";
	for (my $i = 0; $i < $#timestamps; $i++) {
		if ($timestamps[$i] < $timestamp) {
			$activity = $activities[$i];
		} else {
			last;
		}
	}

	return $activity;
}

sub getFrequency() {
	my ($self) = @_;

	return $self->{_Frequency};
}

sub getInputFH() {
	return $input;
}

sub getTimestamp() {
	my ($self) = @_;
	return $self->{_Timestamp};
}

sub setTimestamp() {
	my ($self, $timestamp) = @_;
	$self->{_Timestamp} = $timestamp;
}

sub updateFrequency() {
	my ($self, $new_sample) = @_;

	if ($new_sample == 0 || $self->{_Frequency} > 0) {
		return;
	}

	$self->{_Frequency} = $new_sample;
}

sub end() {
	close($input);
}

1;
