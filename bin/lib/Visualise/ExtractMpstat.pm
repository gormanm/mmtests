package Visualise::ExtractMpstat;
use Visualise::Visualise;
use Visualise::Container;
use Visualise::Extract;
our @ISA = qw(Visualise::Extract);
use strict;

my $frames = 1;
my $startTimestamp = 0;

sub new() {
	my $class = shift;
	my $self = {};
	$self->{_ModuleName} = "ExtractMpstat";

	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self) = @_;

	$self->SUPER::initialise();
}

sub start {
	my ($self, $file) = @_;
	my $line;

	$self->SUPER::start($file);

	# Skip the first entry as it's a header
	my $input = $self->getInputFH();
	$line = <$input>;
	$line = <$input>;
	if ($line !~ /^Linux/) {
		die("Unexpected file format no header, possibly missed data\n");
	}
	$line = <$input>;
	if ($line !~ /^$/) {
		die("Unexpected file format extra data, possibly missed data\n");
	}
}

sub parseOne() {
	my ($self, $model) = @_;
	my $input = $self->getInputFH();
	my $line = <$input>;

	if ($line !~ /^time: ([0-9]+)/) {
		die("Unexpected mpstat input line $line");
	}
	if (!$startTimestamp) {
		$startTimestamp = $1;
	}
	my $timestamp = $1 - $startTimestamp;
	my $container = $model->getModel();
	$container->setContainerTitle("Time: $timestamp " . $self->getActivity($1));
	$self->setTimestamp($timestamp);
	$self->updateFrequency($timestamp);

	while (!eof($input)) {
		$line = <$input>;
		next if $line =~ /%idle/;
		next if $line =~ /all/;
		next if $line =~ /^Linux/;
		last if $line =~ /^$/;

		my @elements = split(/\s+/, $line);
		my $value = 100 - $elements[-1];
		$container->setValue("cpu $elements[1]", $value);
	}
	$container->propogateValues();
	return !eof($input);
}

1;
