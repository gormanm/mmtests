# ExtractFactory.pm
package MMTests::ExtractFactory;
use MMTests::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

sub loadModule($$$) {
	my ($self, $type, $moduleName, $testName, $subheading) = @_;
	printVerbose("Loading module $moduleName\n");

	my $pmName = ucfirst($moduleName);
	$pmName =~ s/-//g;
	$pmName =~ s/Bonnie\+\+/Bonniepp/;
	$type = ucfirst($type);
   	require "MMTests/$type$pmName.pm";
    	$pmName->import();

	my $className = "MMTests::$type$pmName";
	my $classInstance = $className->new(0);
	$classInstance->{_TestName} = $testName;
	$classInstance->initialise($subheading);
	printVerbose("Loaded  module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, $className;
}

1;
