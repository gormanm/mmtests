package Visualise::VisualiseFactory;
use MMTests::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

sub loadModule($$$) {
	my ($self, $type, $moduleName) = @_;
	printVerbose("Loading module $moduleName\n");

	my $pmName = ucfirst($moduleName);
	$pmName =~ s/-//g;
	$type = ucfirst($type);
	printVerbose("Loading perl Visualise/$type$pmName.pm\n");
   	require "Visualise/$type$pmName.pm";
    	$pmName->import();

	my $className = "Visualise::$type$pmName";
	my $classInstance = $className->new(0);
	$classInstance->initialise();
	printVerbose("Loaded  module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, $className;
}

1;
