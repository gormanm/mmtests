# ExtractFactory.pm
package MMTests::ExtractFactory;
use VMR::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

sub loadModule($$$) {
	my ($self, $moduleName, $opt_reportDirectory, $testName) = @_;
	printVerbose("Loading module $moduleName\n");

	my $pmName = $moduleName;
	$pmName = $moduleName;
	$pmName = ucfirst($pmName);
	$pmName =~ s/-//g;
   	require "MMTests/Extract$pmName.pm";
    	$pmName->import();

	my $className = "MMTests::Extract$pmName";
	my $classInstance = $className->new();
	$classInstance->initialise($opt_reportDirectory, $testName);
	printVerbose("Loaded  module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, "MMTests::Extract$pmName";
}

1;
