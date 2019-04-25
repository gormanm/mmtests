# CompareFactory.pm
package MMTests::CompareFactory;
use MMTests::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

sub loadModule($$$) {
	my ($self, $format, $extractModules) = @_;
	printVerbose("Loading compare module\n");

	require "MMTests/Compare.pm";

	my $className = "MMTests::Compare";
	my $classInstance = $className->new();
	$classInstance->initialise($extractModules);
	$classInstance->setFormat($format);
	printVerbose("Loaded  module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, "MMTests::Compare";
}

1;
