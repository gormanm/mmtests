# CompareFactory.pm
package MMTests::CompareFactory;
use VMR::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

sub loadModule($$$) {
	my ($self, $moduleName, $extractModules) = @_;
	printVerbose("Loading module $moduleName\n");

	my $pmName = $moduleName;
	$pmName = ucfirst($pmName);
	$pmName =~ s/-//g;
   	require "MMTests/Compare$pmName.pm";
    	$pmName->import();

	my $className = "MMTests::Compare$pmName";
	my $classInstance = $className->new();
	$classInstance->initialise($extractModules);
	printVerbose("Loaded  module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, "MMTests::Compare$pmName";
}

1;
