package Visualise::Model;
use Visualise::Visualise;
our @ISA = qw(Visualise::Visualise);
use strict;

# Maybe a Container but is whatever the implementation class of
# Model considers to be useful.
my $rootObject;

sub setModel {
	my ($self, $model) = @_;

	$rootObject = $model;
}

sub getModel {
	my ($self) = @_;

	return $rootObject;
}

sub clearValues {
	my ($self) = @_;

	$rootObject->clearValues($rootObject);
}

sub dump {
	my ($self, $model, $field) = @_;

	if (!defined($model)) {
		$model = $rootObject;
	}

	$model->dump(0, $model, $field);
}

1;
