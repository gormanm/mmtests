# MonitorFactory.pm
package MMTests::MonitorFactory;
use VMR::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

my %module_map;

sub loadModule($$$) {
	my ($self, $moduleName, $opt_reportDirectory, $testName) = @_;
	printVerbose("Loading monitor module $moduleName\n");

	my $pmName = $moduleName;
	$pmName = $module_map{$moduleName} if defined $module_map{$moduleName};
	$pmName = ucfirst($pmName);
	$pmName =~ s/-//g;
   	require "MMTests/Monitor$pmName.pm";
    	$pmName->import();

	my $className = "MMTests::Monitor$pmName";
	my $classInstance = $className->new();
	$classInstance->initialise($opt_reportDirectory, $testName);
	printVerbose("Loaded  monitor module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, "MMTests::Monitor$pmName";
}

1;
